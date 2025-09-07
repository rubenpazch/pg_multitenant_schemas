# frozen_string_literal: true

# Load individual task files
Dir[File.join(File.dirname(__FILE__), "*.rake")].each { |file| load file unless file == __FILE__ }

require_relative "../tenant_task_helpers"

namespace :tenants do
  desc "Create new tenant with attributes (JSON format)"
  task :new, [:attributes] => :environment do |_task, args|
    TenantTaskHelpers.create_tenant_with_attributes(args[:attributes])
  end

  desc "Drop tenant schema (DANGEROUS)"
  task :drop, [:schema_name] => :environment do |_task, args|
    TenantTaskHelpers.drop_tenant_schema(args[:schema_name])
  end

  desc "Rollback migrations for a tenant"
  task :rollback, %i[schema_name steps] => :environment do |_task, args|
    steps = (args[:steps] || 1).to_i
    TenantTaskHelpers.rollback_tenant_migrations(args[:schema_name], steps)
  end
end

# Namespace aliases for convenience
namespace :tenants do
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
