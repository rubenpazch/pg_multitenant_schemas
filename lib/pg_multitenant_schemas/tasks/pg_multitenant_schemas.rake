# frozen_string_literal: true

namespace :tenants do
  desc "List all tenant schemas"
  task list: :environment do
    puts "📋 Available tenant schemas:"

    schemas = PgMultitenantSchemas::Migrator.send(:tenant_schemas)

    if schemas.any?
      schemas.each { |schema| puts "  - #{schema}" }
      puts "\n📊 Total: #{schemas.count} tenant schemas"
    else
      puts "  No tenant schemas found"
    end
  end

  desc "Show migration status for all tenants"
  task status: :environment do
    PgMultitenantSchemas::Migrator.migration_status
  end

  desc "Run migrations for all tenant schemas"
  task migrate: :environment do
    PgMultitenantSchemas::Migrator.migrate_all
  end

  desc "Run migrations for a specific tenant"
  task :migrate_tenant, [:schema_name] => :environment do |_task, args|
    schema_name = args[:schema_name]

    if schema_name.blank?
      puts "Usage: rails tenants:migrate_tenant[schema_name]"
      puts "Example: rails tenants:migrate_tenant[acme_corp]"
      exit 1
    end

    PgMultitenantSchemas::Migrator.migrate_tenant(schema_name)
  end

  desc "Setup new tenant with schema and migrations"
  task :create, [:schema_name] => :environment do |_task, args|
    schema_name = args[:schema_name]

    if schema_name.blank?
      puts "Usage: rails tenants:create[schema_name]"
      puts "Example: rails tenants:create[acme_corp]"
      exit 1
    end

    PgMultitenantSchemas::Migrator.setup_tenant(schema_name)
  end

  desc "Setup schemas and run migrations for all existing tenants"
  task setup: :environment do
    PgMultitenantSchemas::Migrator.setup_all_tenants
  end

  desc "Create new tenant with attributes (JSON format)"
  task :new, [:attributes] => :environment do |_task, args|
    attributes_json = args[:attributes]

    if attributes_json.blank?
      puts "Usage: rails tenants:new['{\"subdomain\":\"acme\",\"name\":\"ACME Corp\"}']"
      exit 1
    end

    begin
      attributes = JSON.parse(attributes_json)
      tenant = PgMultitenantSchemas::Migrator.create_tenant_with_schema(attributes)
      puts "🎉 Created tenant: #{tenant.subdomain}"
    rescue JSON::ParserError
      puts "❌ Invalid JSON format"
      exit 1
    rescue StandardError => e
      puts "❌ Error creating tenant: #{e.message}"
      exit 1
    end
  end

  desc "Drop tenant schema (DANGEROUS)"
  task :drop, [:schema_name] => :environment do |_task, args|
    schema_name = args[:schema_name]

    if schema_name.blank?
      puts "Usage: rails tenants:drop[schema_name]"
      exit 1
    end

    if schema_name == "public"
      puts "❌ Cannot drop public schema"
      exit 1
    end

    print "⚠️  This will permanently delete all data in schema '#{schema_name}'. Continue? (y/N): "
    response = $stdin.gets.chomp.downcase

    unless %w[y yes].include?(response)
      puts "❌ Operation cancelled"
      exit 0
    end

    begin
      PgMultitenantSchemas::SchemaSwitcher.drop_schema(schema_name)
      puts "✅ Dropped schema: #{schema_name}"
    rescue StandardError => e
      puts "❌ Error dropping schema #{schema_name}: #{e.message}"
      exit 1
    end
  end

  desc "Rollback migrations for a tenant"
  task :rollback, %i[schema_name steps] => :environment do |_task, args|
    schema_name = args[:schema_name]
    steps = (args[:steps] || 1).to_i

    if schema_name.blank?
      puts "Usage: rails tenants:rollback[schema_name,steps]"
      puts "Example: rails tenants:rollback[acme_corp,2]"
      exit 1
    end

    PgMultitenantSchemas::Migrator.rollback_tenant(schema_name, steps: steps)
  end

  namespace :db do
    desc "Create tenant schema (alias for tenants:create)"
    task :create, [:schema_name] => "tenants:create"

    desc "Run tenant migrations (alias for tenants:migrate)"
    task migrate: "tenants:migrate"

    desc "Check tenant migration status (alias for tenants:status)"
    task status: "tenants:status"

    desc "Setup all tenants (alias for tenants:setup)"
    task setup: "tenants:setup"

    desc "Rollback tenant migrations (alias for tenants:rollback)"
    task :rollback, %i[schema_name steps] => "tenants:rollback"
  end
end

# Legacy namespace for backward compatibility
namespace :pg_multitenant_schemas do
  desc "DEPRECATED: Use 'tenants:list' instead"
  task list_schemas: "tenants:list"

  desc "DEPRECATED: Use 'tenants:migrate' instead"
  task migrate_all: "tenants:migrate"

  desc "DEPRECATED: Use 'tenants:setup' instead"
  task setup: "tenants:setup"

  desc "DEPRECATED: Use 'tenants:migrate_tenant[schema_name]' instead"
  task :migrate_tenant, [:schema_name] => "tenants:migrate_tenant"

  desc "DEPRECATED: Use 'tenants:create[schema_name]' instead"
  task :create_schema, [:schema_name] => "tenants:create"

  desc "DEPRECATED: Use 'tenants:drop[schema_name]' instead"
  task :drop_schema, [:schema_name] => "tenants:drop"
end
