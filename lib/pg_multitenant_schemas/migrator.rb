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

        begin
          switch_to_schema(schema_name)
          ActiveRecord::Base.connection.migration_context.rollback(migration_paths, steps)
          puts "  ✅ Rollback completed" if verbose
        rescue StandardError => e
          puts "  ❌ Rollback failed: #{e.message}" if verbose
          raise
        ensure
          switch_to_schema(original_schema) if original_schema
        end
      end
    end
  end
end
