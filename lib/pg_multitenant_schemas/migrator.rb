# frozen_string_literal: true

module PgMultitenantSchemas
  # Enhanced migration management for multi-tenant schemas
  class Migrator
    class << self
      # Run migrations on all tenant schemas
      def migrate_all(verbose: true, ignore_errors: false)
        schemas = tenant_schemas
        results = []

        puts "🚀 Starting migrations for #{schemas.count} tenant schemas..." if verbose

        schemas.each do |schema|
          result = migrate_tenant(schema, verbose: verbose, raise_on_error: !ignore_errors)
          results << result
        end

        summary = results.group_by { |r| r[:status] }.transform_values(&:count)

        if verbose
          puts "\n📊 Migration Summary:"
          puts "  ✅ Successful: #{summary[:success] || 0}"
          puts "  ❌ Failed: #{summary[:error] || 0}"
          puts "  ⏭️  Skipped: #{summary[:skipped] || 0}"
        end

        results
      end

      # Run migrations on a specific tenant schema
      def migrate_tenant(schema_name, verbose: true, raise_on_error: true)
        puts "  📦 Migrating schema: #{schema_name}" if verbose

        unless schema_exists?(schema_name)
          message = "Schema '#{schema_name}' does not exist"
          puts "    ⚠️  #{message}" if verbose
          raise StandardError, message if raise_on_error

          return { schema: schema_name, status: :skipped, message: message }
        end

        original_schema = current_schema

        begin
          # Switch to tenant schema and run migrations
          switch_to_schema(schema_name)

          # Check if migrations are needed
          pending_count = pending_migrations.count

          if pending_count.zero?
            message = "No pending migrations"
            puts "    ✅ #{message}" if verbose
            return { schema: schema_name, status: :success, message: message }
          end

          # Run migrations
          run_migrations

          message = "#{pending_count} migrations applied successfully"
          puts "    ✅ #{message}" if verbose
          { schema: schema_name, status: :success, message: message }
        rescue StandardError => e
          message = "Migration failed: #{e.message}"
          puts "    ❌ #{message}" if verbose
          raise e if raise_on_error

          { schema: schema_name, status: :error, message: message, error: e }
        ensure
          # Always restore original schema
          switch_to_schema(original_schema) if original_schema
        end
      end

      # Create schema and run initial migrations
      def setup_tenant(schema_name, verbose: true)
        puts "🏗️  Setting up tenant: #{schema_name}" if verbose

        begin
          # Create schema if it doesn't exist
          if schema_exists?(schema_name)
            puts "  ℹ️  Schema already exists" if verbose
          else
            create_schema(schema_name)
            puts "  ✅ Schema created" if verbose
          end

          # Run migrations
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
        raise "Tenant model not found. Please define a Tenant model." unless defined?(Tenant)

        tenants = Tenant.all
        puts "🏗️  Setting up #{tenants.count} tenants..." if verbose

        results = tenants.map do |tenant|
          schema_name = extract_schema_name(tenant)
          setup_tenant(schema_name, verbose: verbose)
        end

        summary = results.group_by { |r| r[:status] }.transform_values(&:count)

        if verbose
          puts "\n📊 Setup Summary:"
          puts "  ✅ Successful: #{summary[:success] || 0}"
          puts "  ❌ Failed: #{summary[:error] || 0}"
        end

        results
      end

      # Check migration status across all tenants
      def migration_status(verbose: true)
        schemas = tenant_schemas
        results = []

        schemas.each do |schema|
          original_schema = current_schema

          begin
            switch_to_schema(schema)
            pending = pending_migrations
            applied = applied_migrations

            results << {
              schema: schema,
              pending_count: pending.count,
              applied_count: applied.count,
              status: pending.any? ? :pending : :up_to_date
            }
          rescue StandardError => e
            results << {
              schema: schema,
              error: e.message,
              status: :error
            }
          ensure
            switch_to_schema(original_schema) if original_schema
          end
        end

        if verbose
          puts "📋 Migration Status Report:"
          results.each do |result|
            case result[:status]
            when :up_to_date
              puts "  ✅ #{result[:schema]}: Up to date (#{result[:applied_count]} applied)"
            when :pending
              puts "  ⏳ #{result[:schema]}: #{result[:pending_count]} pending, #{result[:applied_count]} applied"
            when :error
              puts "  ❌ #{result[:schema]}: Error - #{result[:error]}"
            end
          end
        end

        results
      end

      # Create a new tenant with schema and migrations
      def create_tenant_with_schema(attributes, verbose: true)
        raise "Tenant model not found. Please define a Tenant model." unless defined?(Tenant)

        tenant = Tenant.create!(attributes)
        schema_name = extract_schema_name(tenant)

        puts "🆕 Creating new tenant: #{schema_name}" if verbose

        setup_tenant(schema_name, verbose: verbose)

        puts "🎉 New tenant created successfully!" if verbose
        tenant
      end

      # Rollback migrations for a tenant
      def rollback_tenant(schema_name, steps: 1, verbose: true)
        puts "↩️  Rolling back #{steps} migration(s) for: #{schema_name}" if verbose

        raise "Schema '#{schema_name}' does not exist" unless schema_exists?(schema_name)

        original_schema = current_schema

        begin
          switch_to_schema(schema_name)

          # Perform rollback
          if Rails.version >= "8.0"
            ActiveRecord::Base.connection.migration_context.rollback(steps)
          else
            ActiveRecord::Migrator.rollback(migration_paths, steps)
          end

          puts "  ✅ Rollback completed" if verbose
        ensure
          switch_to_schema(original_schema) if original_schema
        end
      end

      private

      def tenant_schemas
        SchemaSwitcher.connection.execute(<<~SQL).map { |row| row["schema_name"] }
          SELECT schema_name#{" "}
          FROM information_schema.schemata#{" "}
          WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'public')#{" "}
          AND schema_name NOT LIKE 'pg_%'
          ORDER BY schema_name
        SQL
      end

      def schema_exists?(schema_name)
        SchemaSwitcher.schema_exists?(schema_name)
      end

      def create_schema(schema_name)
        SchemaSwitcher.create_schema(schema_name)
      end

      def current_schema
        SchemaSwitcher.current_schema
      end

      def switch_to_schema(schema_name)
        SchemaSwitcher.switch_schema(schema_name)
      end

      def pending_migrations
        if Rails.version >= "8.0"
          ActiveRecord::Base.connection.migration_context.pending_migrations
        else
          ActiveRecord::Migrator.open(migration_paths).pending_migrations
        end
      end

      def applied_migrations
        if Rails.version >= "8.0"
          ActiveRecord::Base.connection.migration_context.get_all_versions
        else
          ActiveRecord::Base.connection.select_values(
            "SELECT version FROM #{ActiveRecord::Migrator.schema_migrations_table_name}"
          )
        end
      end

      def run_migrations
        if Rails.version >= "8.0"
          ActiveRecord::Base.connection.migration_context.migrate
        else
          ActiveRecord::Migrator.migrate(migration_paths)
        end
      end

      def migration_paths
        Rails.application.paths["db/migrate"]
      end

      def extract_schema_name(tenant)
        # Default to subdomain, but allow customization
        if tenant.respond_to?(:schema_name) && tenant.schema_name.present?
          tenant.schema_name
        elsif tenant.respond_to?(:subdomain) && tenant.subdomain.present?
          tenant.subdomain
        else
          raise "Tenant must have either a 'schema_name' or 'subdomain' attribute"
        end
      end
    end
  end
end
