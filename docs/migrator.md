# Migrator - Automated Migration Management

**File**: `lib/pg_multitenant_schemas/migrator.rb`

## 📋 Overview

The `Migrator` class provides comprehensive automated migration management for multi-tenant applications. It handles running migrations across all tenant schemas, setting up new tenants, and tracking migration status.

## 🎯 Purpose

- **Bulk Migration**: Run migrations across all tenant schemas with single command
- **Tenant Setup**: Automated tenant creation with schema and migrations
- **Status Tracking**: Monitor migration status across all tenants
- **Error Resilience**: Handle migration failures gracefully per tenant
- **Progress Reporting**: Detailed feedback during migration operations

## 🔧 Key Methods

### Core Migration Operations

```ruby
# Migrate all tenant schemas
Migrator.migrate_all

# Migrate specific tenant
Migrator.migrate_tenant('acme_corp')

# Check migration status across all tenants
Migrator.migration_status

# Setup new tenant (create schema + run migrations)
Migrator.setup_tenant('new_tenant')
```

### Tenant Management

```ruby
# Setup all existing tenants
Migrator.setup_all_tenants

# Create tenant with attributes and schema
Migrator.create_tenant_with_schema({
  subdomain: 'acme',
  name: 'ACME Corporation'
})

# Rollback specific tenant
Migrator.rollback_tenant('tenant_name', steps: 2)
```

## 🏗️ Implementation Details

### Migration Execution Flow

```ruby
def migrate_all
  puts "🚀 Starting migration for all tenant schemas..."
  
  tenant_schemas.each do |schema|
    puts "📦 Migrating schema: #{schema}"
    
    migrate_tenant(schema)
  end
  
  puts "✅ Migration completed for all schemas"
end
```

### Error Handling Strategy

The Migrator implements robust error handling:

- **Per-Tenant Isolation**: Failures in one tenant don't affect others
- **Detailed Error Reporting**: Specific error messages per tenant
- **Continue on Error**: Migration continues for remaining tenants
- **Transaction Safety**: Each tenant migration is self-contained

### Progress Tracking

```ruby
def migration_status
  puts "📊 Migration Status Report"
  
  tenant_schemas.each do |schema|
    pending = pending_migrations_for_schema(schema)
    
    if pending.empty?
      puts "▸ #{schema}: ✅ Up to date"
    else
      puts "▸ #{schema}: ⚠️  #{pending.count} pending migrations"
    end
  end
end
```

## 🔄 Usage Patterns

### Daily Operations

```ruby
# Check what needs migration
PgMultitenantSchemas::Migrator.migration_status

# Run migrations across all tenants
PgMultitenantSchemas::Migrator.migrate_all

# Setup new tenant
PgMultitenantSchemas::Migrator.setup_tenant('new_client')
```

### Deployment Workflow

```ruby
# In deployment script
namespace :deploy do
  task :migrate_tenants do
    PgMultitenantSchemas::Migrator.migrate_all
  end
end
```

### New Tenant Onboarding

```ruby
# Complete tenant setup
tenant_attributes = {
  subdomain: 'newco',
  name: 'New Company Ltd',
  domain: 'newco.com'
}

tenant = PgMultitenantSchemas::Migrator.create_tenant_with_schema(tenant_attributes)
puts "✅ Tenant #{tenant.subdomain} ready for use"
```

### Rollback Operations

```ruby
# Rollback specific tenant
PgMultitenantSchemas::Migrator.rollback_tenant('acme_corp', steps: 1)

# Check status after rollback
PgMultitenantSchemas::Migrator.migration_status
```

## 🎛️ Configuration Integration

The Migrator respects global configuration:

```ruby
PgMultitenantSchemas.configure do |config|
  config.default_schema = 'public'
  config.tenant_model = 'Tenant'
  config.connection_class = 'ApplicationRecord'
end
```

## 📊 Status Reporting

### Migration Status Output

```
📊 Migration Status Report
▸ acme_corp: ✅ Up to date (5 migrations)
▸ beta_corp: ⚠️  2 pending migrations
  - 20241201120000_add_feature_flags
  - 20241202100000_update_user_fields
▸ demo_corp: ✅ Up to date (5 migrations)

📈 Overall: 2/3 tenants current, 2 migrations pending
```

### Migration Progress Output

```
🚀 Starting migration for all tenant schemas...

📦 Migrating schema: acme_corp
  ✓ Running migration 20241201120000_add_feature_flags
  ✓ Running migration 20241202100000_update_user_fields
  ✅ Completed migration for acme_corp

📦 Migrating schema: beta_corp
  ✓ Running migration 20241201120000_add_feature_flags
  ✗ Error in migration 20241202100000_update_user_fields: column already exists
  ⚠️  Continuing with next tenant...

✅ Migration completed for all schemas
📊 Summary: 1/2 tenants migrated successfully
```

## 🔍 Advanced Features

### Custom Migration Paths

```ruby
# Override migration paths if needed
class CustomMigrator < PgMultitenantSchemas::Migrator
  private
  
  def migration_paths
    [
      Rails.root.join('db', 'migrate'),
      Rails.root.join('db', 'tenant_migrations')
    ]
  end
end
```

### Migration Callbacks

```ruby
# Add hooks for migration events
module MigrationHooks
  def self.before_tenant_migration(schema_name)
    Rails.logger.info "Starting migration for #{schema_name}"
  end
  
  def self.after_tenant_migration(schema_name, success)
    status = success ? "SUCCESS" : "FAILED"
    Rails.logger.info "Migration for #{schema_name}: #{status}"
  end
end
```

### Batch Processing

```ruby
# Process tenants in batches for large installations
def migrate_all_batched(batch_size: 10)
  tenant_schemas.each_slice(batch_size) do |batch|
    batch.each { |schema| migrate_tenant(schema) }
    sleep(1)  # Brief pause between batches
  end
end
```

## 🚨 Important Considerations

### Performance

- **Parallel Processing**: Consider parallelization for large tenant counts
- **Resource Usage**: Monitor database connections during bulk operations
- **Timing**: Run during low-traffic periods for production

### Data Integrity

- **Backup Strategy**: Ensure proper backups before major migrations
- **Testing**: Test migrations on staging environment with production data
- **Rollback Plan**: Have rollback procedures for failed migrations

### Monitoring

- **Log Analysis**: Monitor migration logs for patterns and issues
- **Alert Setup**: Set up alerts for migration failures
- **Performance Metrics**: Track migration duration and resource usage

## 🔧 Troubleshooting

### Common Issues

**Migration Stuck**
```ruby
# Check for long-running queries
ActiveRecord::Base.connection.execute("SELECT * FROM pg_stat_activity WHERE state = 'active'")
```

**Schema Not Found**
```ruby
# Verify schema exists
if !PgMultitenantSchemas::SchemaSwitcher.schema_exists?('tenant_name')
  PgMultitenantSchemas::Migrator.setup_tenant('tenant_name')
end
```

**Permission Errors**
```ruby
# Check database permissions
ActiveRecord::Base.connection.execute("SELECT has_schema_privilege('tenant_schema', 'USAGE')")
```

## 🔗 Related Components

- **[SchemaSwitcher](schema_switcher.md)**: Core schema operations used by Migrator
- **[Context](context.md)**: Tenant context management during migrations
- **[Configuration](configuration.md)**: Migrator configuration options
- **[Rails Integration](rails_integration.md)**: Framework integration features

## 📝 Examples

See [examples/migration_workflow.rb](../examples/) for complete usage examples and [rake tasks documentation](../lib/pg_multitenant_schemas/tasks/) for command-line usage.
