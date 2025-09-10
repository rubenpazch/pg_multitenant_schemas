# frozen_string_literal: true

module PgMultitenantSchemas
  # Schema operations for migration management
  module MigrationSchemaOperations
    private

    # Delegate schema operations to SchemaSwitcher
    def switch_to_schema(schema_name)
      SchemaSwitcher.switch_schema(schema_name)
    end

    def create_schema(schema_name)
      SchemaSwitcher.create_schema(schema_name)
    end

    def schema_exists?(schema_name)
      SchemaSwitcher.schema_exists?(schema_name)
    end

    def current_schema
      SchemaSwitcher.current_schema
    end

    def tenant_schemas
      SchemaSwitcher.list_schemas.reject do |schema|
        %w[information_schema pg_catalog public pg_temp_1 pg_toast_temp_1].include?(schema) ||
          schema.start_with?("pg_toast")
      end
    end

    def extract_schema_name(tenant)
      tenant.respond_to?(:subdomain) ? tenant.subdomain : tenant.to_s
    end

    def run_migrations
      # Use the migration context to run migrations
      migration_context = get_migration_context
      return unless migration_context
      
      migration_context.migrate
    end

    def pending_migrations
      migration_context = get_migration_context
      return [] unless migration_context
      
      all_migrations = migration_context.migrations
      applied_versions = get_applied_versions
      
      all_migrations.reject do |migration|
        applied_versions.include?(migration.version)
      end
    end

    def applied_migrations
      get_applied_versions
    end

    def migration_paths
      migration_context = get_migration_context
      if migration_context && migration_context.respond_to?(:migrations_paths)
        migration_context.migrations_paths
      else
        # Fallback to default Rails migration paths
        if defined?(Rails) && Rails.application
          Rails.application.paths["db/migrate"].expanded
        else
          ["db/migrate"]
        end
      end
    end

    def get_migration_context
      # Return nil if ActiveRecord is not available (for tests)
      return nil unless defined?(ActiveRecord::Base)
      
      # Rails 8 compatibility: Try multiple approaches
      if ActiveRecord::Base.respond_to?(:migration_context)
        # Rails 8+: Try base migration context first
        ActiveRecord::Base.migration_context
      elsif ActiveRecord::Base.connection.respond_to?(:migration_context)
        # Rails 7: Use connection migration context
        ActiveRecord::Base.connection.migration_context
      elsif defined?(ActiveRecord::MigrationContext)
        # Fallback: Create a new migration context with default paths
        paths = if defined?(Rails) && Rails.application
                   Rails.application.paths["db/migrate"].expanded
                 else
                   ["db/migrate"]
                 end
        ActiveRecord::MigrationContext.new(paths)
      else
        # Last resort fallback
        nil
      end
    rescue StandardError => e
      # Use explicit Rails logger to avoid namespace conflicts
      ::Rails.logger&.warn("Failed to get migration context: #{e.message}") if defined?(::Rails)
      nil
    end

    # Get applied migration versions with Rails 8 compatibility
    def get_applied_versions
      # Return empty array if ActiveRecord is not available (for tests)
      return [] unless defined?(ActiveRecord::Base)
      
      # Try using migration context first (for tests and Rails 7)
      migration_context = get_migration_context
      if migration_context && migration_context.respond_to?(:get_all_versions)
        return migration_context.get_all_versions
      end
      
      # Fallback to direct database query (Rails 8)
      connection = ActiveRecord::Base.connection
      table_name = "schema_migrations"
      
      # Ensure the schema_migrations table exists
      unless connection.table_exists?(table_name)
        # Create the table if it doesn't exist
        connection.create_table(table_name, id: false) do |t|
          t.string :version, null: false
        end
        connection.add_index(table_name, :version, unique: true, name: "unique_schema_migrations")
        return []
      end
      
      # Query the table directly for maximum compatibility
      connection.select_values("SELECT version FROM #{table_name} ORDER BY version")
    rescue StandardError => e
      # If anything fails, return empty array
      ::Rails.logger&.warn("Failed to get applied versions: #{e.message}") if defined?(::Rails)
      []
    end
  end
end
