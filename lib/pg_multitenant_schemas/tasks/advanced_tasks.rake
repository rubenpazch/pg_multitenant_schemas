# frozen_string_literal: true

# Advanced tenant management tasks
namespace :tenants do
  desc "Run migrations for a specific tenant"
  task :migrate_tenant, [:schema_name] => :environment do |_task, args|
    require_relative "../tenant_task_helpers"
    TenantTaskHelpers.migrate_specific_tenant(args[:schema_name])
  end

  desc "Setup new tenant with schema and migrations"
  task :create, [:schema_name] => :environment do |_task, args|
    require_relative "../tenant_task_helpers"
    TenantTaskHelpers.create_tenant_with_schema(args[:schema_name])
  end

  desc "Setup schemas and run migrations for all existing tenants"
  task setup: :environment do
    PgMultitenantSchemas::Migrator.setup_all_tenants
  end
end
