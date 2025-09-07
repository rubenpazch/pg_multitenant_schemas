# frozen_string_literal: true

module PgMultitenantSchemas
  # Module for executing migration operations
  # Handles the core migration execution and error handling logic
  module MigrationExecutor
    private

    def process_schemas_migration(schemas, verbose, ignore_errors)
      puts "🚀 Starting migrations for #{schemas.count} tenant schemas..." if verbose

      schemas.map do |schema|
        migrate_tenant(schema, verbose: verbose, raise_on_error: !ignore_errors)
      end
    end

    def handle_missing_schema(schema_name, verbose, raise_on_error)
      message = "Schema '#{schema_name}' does not exist"
      puts "    ⚠️  #{message}" if verbose
      raise StandardError, message if raise_on_error

      { schema: schema_name, status: :skipped, message: message }
    end

    def execute_tenant_migration(schema_name, verbose, raise_on_error)
      puts "  📦 Migrating schema: #{schema_name}" if verbose
      original_schema = current_schema

      begin
        result = perform_migration_for_schema(schema_name, verbose)
        puts "    ✅ Migration completed" if verbose && result[:status] == :success
        result
      rescue StandardError => e
        handle_migration_error(schema_name, e, verbose, raise_on_error)
      ensure
        switch_to_schema(original_schema) if original_schema
      end
    end

    def perform_migration_for_schema(schema_name, verbose)
      switch_to_schema(schema_name)
      pending_count = pending_migrations.count

      if pending_count.zero?
        puts "    ℹ️  No pending migrations" if verbose
        return { schema: schema_name, status: :success, message: "No pending migrations" }
      end

      run_migrations
      { schema: schema_name, status: :success, message: "#{pending_count} migrations applied" }
    end

    def handle_migration_error(schema_name, error, verbose, raise_on_error)
      message = "Migration failed: #{error.message}"
      puts "    ❌ #{message}" if verbose
      raise error if raise_on_error

      { schema: schema_name, status: :error, message: message }
    end

    def create_tenant_schema_if_needed(schema_name, verbose)
      if schema_exists?(schema_name)
        puts "  ℹ️  Schema already exists" if verbose
      else
        create_schema(schema_name)
        puts "  ✅ Schema created" if verbose
      end
    end

    def validate_tenant_model_exists
      raise "Tenant model not found. Please define a Tenant model." unless defined?(Tenant)
    end

    def process_setup_for_tenants(tenants, verbose)
      tenants.map do |tenant|
        schema_name = extract_schema_name(tenant)
        setup_tenant(schema_name, verbose: verbose)
      end
    end
  end
end
