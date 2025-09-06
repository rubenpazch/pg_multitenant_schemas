# frozen_string_literal: true

namespace :pg_multitenant_schemas do
  desc "List all tenant schemas"
  task :list_schemas => :environment do
    puts "Available tenant schemas:"
    
    connection = ActiveRecord::Base.connection
    schemas = connection.execute(
      "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast_temp_1', 'pg_temp_1', 'public') AND schema_name NOT LIKE 'pg_toast%'"
    ).map { |row| row['schema_name'] }
    
    if schemas.any?
      schemas.each { |schema| puts "  - #{schema}" }
    else
      puts "  No tenant schemas found"
    end
  end

  desc "Create schema for a tenant"
  task :create_schema, [:schema_name] => :environment do |task, args|
    schema_name = args[:schema_name]
    
    if schema_name.blank?
      puts "Usage: rails pg_multitenant_schemas:create_schema[schema_name]"
      exit 1
    end
    
    begin
      connection = ActiveRecord::Base.connection
      PgMultitenantSchemas::SchemaSwitcher.create_schema(connection, schema_name)
      puts "Created schema: #{schema_name}"
    rescue => e
      puts "Error creating schema #{schema_name}: #{e.message}"
      exit 1
    end
  end

  desc "Drop schema for a tenant"
  task :drop_schema, [:schema_name] => :environment do |task, args|
    schema_name = args[:schema_name]
    
    if schema_name.blank?
      puts "Usage: rails pg_multitenant_schemas:drop_schema[schema_name]"
      exit 1
    end
    
    if schema_name == 'public'
      puts "Cannot drop public schema"
      exit 1
    end
    
    begin
      connection = ActiveRecord::Base.connection
      PgMultitenantSchemas::SchemaSwitcher.drop_schema(connection, schema_name)
      puts "Dropped schema: #{schema_name}"
    rescue => e
      puts "Error dropping schema #{schema_name}: #{e.message}"
      exit 1
    end
  end

  desc "Run migrations for all tenant schemas"
  task :migrate_all => :environment do
    puts "Running migrations for all tenant schemas..."
    
    connection = ActiveRecord::Base.connection
    schemas = connection.execute(
      "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast_temp_1', 'pg_temp_1', 'public') AND schema_name NOT LIKE 'pg_toast%'"
    ).map { |row| row['schema_name'] }
    
    original_schema = PgMultitenantSchemas.current_schema rescue 'public'
    
    schemas.each do |schema|
      puts "Migrating schema: #{schema}"
      begin
        PgMultitenantSchemas.with_tenant(schema) do
          # Rails 8 compatible migration execution
          if Rails.version >= "8.0"
            # Use Rails 8 migration API
            ActiveRecord::Tasks::DatabaseTasks.migrate
          else
            # Fallback for older Rails versions
            ActiveRecord::Migrator.migrate(Rails.application.paths["db/migrate"])
          end
        end
        puts "  ✓ Completed migration for #{schema}"
      rescue => e
        puts "  ✗ Error migrating #{schema}: #{e.message}"
      end
    end
    
    # Restore original schema
    PgMultitenantSchemas.current_schema = original_schema if defined?(PgMultitenantSchemas)
    
    puts "Completed migrations for #{schemas.count} schemas"
  end

  desc "Setup multitenancy - create tenant schemas for existing tenants"
  task :setup => :environment do
    puts "Setting up multitenancy schemas..."
    
    if defined?(Tenant)
      tenants = Tenant.all
      
      tenants.each do |tenant|
        begin
          puts "Creating schema for tenant: #{tenant.subdomain}"
          PgMultitenantSchemas::SchemaSwitcher.create_schema(
            ActiveRecord::Base.connection, 
            tenant.subdomain
          )
          puts "  ✓ Schema created for #{tenant.subdomain}"
        rescue => e
          if e.message.include?("already exists")
            puts "  - Schema #{tenant.subdomain} already exists"
          else
            puts "  ✗ Could not create schema for #{tenant.subdomain}: #{e.message}"
          end
        end
      end
      
      puts "Setup completed for #{tenants.count} tenants"
    else
      puts "Tenant model not found. Make sure your Tenant model is defined."
    end
  end

  desc "Run migrations for a specific tenant schema"
  task :migrate_tenant, [:schema_name] => :environment do |task, args|
    schema_name = args[:schema_name]
    
    if schema_name.blank?
      puts "Usage: rails pg_multitenant_schemas:migrate_tenant[schema_name]"
      exit 1
    end
    
    puts "Running migrations for tenant: #{schema_name}"
    
    begin
      PgMultitenantSchemas.with_tenant(schema_name) do
        # Rails 8 compatible migration execution
        if Rails.version >= "8.0"
          ActiveRecord::Tasks::DatabaseTasks.migrate
        else
          ActiveRecord::Migrator.migrate(Rails.application.paths["db/migrate"])
        end
      end
      puts "✓ Completed migration for #{schema_name}"
    rescue => e
      puts "✗ Error migrating #{schema_name}: #{e.message}"
      exit 1
    end
  end
end
