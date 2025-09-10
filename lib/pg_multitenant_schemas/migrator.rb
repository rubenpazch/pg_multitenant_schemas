# frozen_string_literal: true

require_relative "migration_status_reporter"
require_relative "migration_schema_operations"
require_relative "migration_executor"
require_relative "migration_display_reporter"

module PgMultitenantSchemas
  # Enhanced migration management for multi-tenant schemas
  # Provides automated migration operations across tenant schemas
  class Migrator
    extend MigrationStatusReporter
    extend MigrationSchemaOperations
    extend MigrationExecutor
    extend MigrationDisplayReporter

    class << self
      # Run migrations on all tenant schemas
      def migrate_all(verbose: true, ignore_errors: false)
        schemas = tenant_schemas
        results = process_schemas_migration(schemas, verbose, ignore_errors)

        display_migration_summary(results, verbose)
        results
      end

      # Run migrations on a specific tenant schema
      def migrate_tenant(schema_name, verbose: true, raise_on_error: true)
        return handle_missing_schema(schema_name, verbose, raise_on_error) unless schema_exists?(schema_name)

        execute_tenant_migration(schema_name, verbose, raise_on_error)
      end

      # Setup tenant with schema creation and migrations
      def setup_tenant(schema_name, verbose: true)
        puts "🏗️  Setting up tenant: #{schema_name}" if verbose

        begin
          create_tenant_schema_if_needed(schema_name, verbose)
          result = migrate_tenant(schema_name, verbose: verbose)
          puts "  🎉 Tenant setup completed!" if verbose
          result
        rescue StandardError => e
          puts "  ❌ Setup failed: #{e.message}" if verbose
          raise
        end
      end

      # Setup all tenants from Tenant model
      def setup_all_tenants(verbose: true)
        validate_tenant_model_exists
        tenants = Tenant.all
        puts "🏗️  Setting up #{tenants.count} tenants..." if verbose

        results = process_setup_for_tenants(tenants, verbose)
        display_setup_summary(results, verbose)
        results
      end

      # Create a new tenant with schema and migrations
      def create_tenant_with_schema(attributes, verbose: true)
        validate_tenant_model_exists
        tenant = Tenant.create!(attributes)
        schema_name = extract_schema_name(tenant)

        puts "🆕 Creating new tenant: #{schema_name}" if verbose
        setup_tenant(schema_name, verbose: verbose)
        tenant
      end

      # Rollback migrations for a specific tenant
      def rollback_tenant(schema_name, steps: 1, verbose: true)
        puts "⏪ Rolling back #{steps} steps for #{schema_name}" if verbose
        original_schema = current_schema

        perform_rollback(schema_name, steps, verbose)
      ensure
        switch_to_schema(original_schema) if original_schema
      end

      private

      def perform_rollback(schema_name, steps, verbose)
        switch_to_schema(schema_name)
        migration_context_obj = migration_context

        unless migration_context_obj
          puts "  ❌ Cannot rollback: migration context not available" if verbose
          return
        end

        migration_context_obj.rollback(migration_paths, steps)
        puts "  ✅ Rollback completed" if verbose
      rescue StandardError => e
        puts "  ❌ Rollback failed: #{e.message}" if verbose
        raise
      end

      def migration_context
        # Return nil if ActiveRecord is not available (for tests)
        return nil unless defined?(ActiveRecord::Base)

        # Rails 8 compatibility: Try multiple approaches
        find_migration_context
      rescue StandardError => e
        # Use explicit Rails logger to avoid namespace conflicts
        ::Rails.logger&.warn("Failed to get migration context: #{e.message}") if defined?(::Rails)
        nil
      end

      def find_migration_context
        if ActiveRecord::Base.respond_to?(:migration_context)
          # Rails 8+: Try base migration context first
          ActiveRecord::Base.migration_context
        elsif ActiveRecord::Base.connection.respond_to?(:migration_context)
          # Rails 7: Use connection migration context
          ActiveRecord::Base.connection.migration_context
        elsif defined?(ActiveRecord::MigrationContext)
          # Fallback: Create a new migration context with default paths
          create_fallback_migration_context
        end
      end

      def create_fallback_migration_context
        paths = if defined?(::Rails) && ::Rails.application
                  ::Rails.application.paths["db/migrate"].expanded
                else
                  ["db/migrate"]
                end
        ActiveRecord::MigrationContext.new(paths)
      end

      def migration_paths
        migration_context_obj = migration_context
        if migration_context_obj.respond_to?(:migrations_paths)
          migration_context_obj.migrations_paths
        elsif defined?(::Rails) && ::Rails.application
          # Fallback to default Rails migration paths
          ::Rails.application.paths["db/migrate"].expanded
        else
          ["db/migrate"]
        end
      end
    end
  end
end
