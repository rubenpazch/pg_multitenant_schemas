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
      ActiveRecord::Base.connection.migrate
    end

    def pending_migrations
      ActiveRecord::Base.connection.migration_context.migrations.reject do |migration|
        ActiveRecord::Base.connection.migration_context.get_all_versions.include?(migration.version)
      end
    end

    def applied_migrations
      ActiveRecord::Base.connection.migration_context.get_all_versions
    end

    def migration_paths
      ActiveRecord::Base.connection.migration_context.migrations_paths
    end
  end
end
