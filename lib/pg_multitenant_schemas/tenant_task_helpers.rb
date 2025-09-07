# frozen_string_literal: true

# Tenant task helper methods
module TenantTaskHelpers
  class << self
    def list_tenant_schemas
      puts "📋 Available tenant schemas:"

      schemas = PgMultitenantSchemas::Migrator.send(:tenant_schemas)

      if schemas.any?
        schemas.each { |schema| puts "  - #{schema}" }
        puts "\n📊 Total: #{schemas.count} tenant schemas"
      else
        puts "  No tenant schemas found"
      end
    end

    def migrate_specific_tenant(schema_name)
      if schema_name.blank?
        puts "Usage: rails tenants:migrate_tenant[schema_name]"
        puts "Example: rails tenants:migrate_tenant[acme_corp]"
        exit 1
      end

      PgMultitenantSchemas::Migrator.migrate_tenant(schema_name)
    end

    def create_tenant_with_schema(schema_name)
      if schema_name.blank?
        puts "Usage: rails tenants:create[schema_name]"
        puts "Example: rails tenants:create[acme_corp]"
        exit 1
      end

      PgMultitenantSchemas::Migrator.setup_tenant(schema_name)
    end

    def create_tenant_with_attributes(attributes_json)
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

    def drop_tenant_schema(schema_name)
      if schema_name.blank?
        puts "Usage: rails tenants:drop[schema_name]"
        exit 1
      end

      if schema_name == "public"
        puts "❌ Cannot drop public schema"
        exit 1
      end

      confirm_schema_drop(schema_name)
    end

    def rollback_tenant_migrations(schema_name, steps)
      if schema_name.blank?
        puts "Usage: rails tenants:rollback[schema_name,steps]"
        puts "Example: rails tenants:rollback[acme_corp,2]"
        exit 1
      end

      PgMultitenantSchemas::Migrator.rollback_tenant(schema_name, steps: steps)
    end

    private

    def confirm_schema_drop(schema_name)
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
  end
end
