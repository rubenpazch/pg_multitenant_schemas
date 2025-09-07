# frozen_string_literal: true

# Basic tenant management tasks
namespace :tenants do
  desc "List all tenant schemas"
  task list: :environment do
    require_relative "../tenant_task_helpers"
    TenantTaskHelpers.list_tenant_schemas
  end

  desc "Show migration status for all tenants"
  task status: :environment do
    PgMultitenantSchemas::Migrator.migration_status
  end

  desc "Run migrations for all tenant schemas"
  task migrate: :environment do
    PgMultitenantSchemas::Migrator.migrate_all
  end
end
