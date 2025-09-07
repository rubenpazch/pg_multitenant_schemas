# PgMultitenantSchemas

[![Gem Version](https://badge.fury.io/rb/pg_multitenant_schemas.svg)](https://badge.fury.io/rb/pg_multitenant_schemas)
[![Ruby](https://github.com/yourusername/pg_multitenant_schemas/actions/workflows/main.yml/badge.svg)](https://github.com/yourusername/pg_multitenant_schemas/actions/workflows/main.yml)

A modern Ruby gem that provides PostgreSQL schema-based multitenancy with automatic tenant resolution and schema switching. Built for Rails 8+ and Ruby 3.3+, focusing on security, performance, and developer experience.

## ✨ Features

- 🏢 **Schema-based multitenancy** - Complete tenant isolation using PostgreSQL schemas
- 🔄 **Automatic schema switching** - Seamlessly switch between tenant schemas  
- 🌐 **Subdomain resolution** - Extract tenant from request subdomains
- � **Rails 8+ optimized** - Built for modern Rails applications
- �️ **Security-first design** - Database-level tenant isolation
- 🧵 **Thread-safe** - Safe for concurrent operations
- 📝 **Comprehensive logging** - Track schema operations
- ⚡ **High performance** - Minimal overhead with clean API

## 📋 Requirements

## Requirements

- Ruby 3.4+
- Rails 8.0+
- PostgreSQL 12+
- **pg gem**: 1.5 or higher

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pg_multitenant_schemas'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install pg_multitenant_schemas
```

## Configuration

Configure the gem in your Rails initializer (`config/initializers/pg_multitenant_schemas.rb`):

```ruby
PgMultitenantSchemas.configure do |config|
  config.connection_class = 'ApplicationRecord'  # or 'ActiveRecord::Base'
  config.tenant_model_class = 'Tenant'           # your tenant model
  config.default_schema = 'public'
  config.excluded_subdomains = ['www', 'api', 'admin']
  config.development_fallback = true            # for development
  config.auto_create_schemas = true             # automatically create missing schemas
end
```

## Usage

### Migration Management

The gem provides automated migration management across all tenant schemas:

#### Running Migrations

```bash
# Migrate all tenant schemas at once (recommended)
rails tenants:migrate

# Migrate a specific tenant
rails tenants:migrate_tenant[acme_corp]

# Check migration status across all tenants
rails tenants:status
```

#### Setting Up New Tenants

```bash
# Create new tenant with full setup (schema + migrations)
rails tenants:create[new_tenant]

# Create tenant with attributes using JSON
rails tenants:new['{"subdomain":"acme","name":"ACME Corp","domain":"acme.com"}']

# Setup schemas for all existing tenants (migration from single-tenant)
rails tenants:setup
```

#### Migration Workflow

1. **Create your migration** as usual:
   ```bash
   rails generate migration AddEmailToUsers email:string
   ```

2. **Deploy to all tenants** with a single command:
   ```bash
   rails tenants:migrate
   ```

3. **Check status** to verify migrations across tenants:
   ```bash
   rails tenants:status
   ```

   This shows detailed migration status:
   ```
   📊 Migration Status Report
   ▸ acme_corp: ✅ Up to date (5 migrations)
   ▸ beta_corp: ⚠️  2 pending migrations
   ▸ demo_corp: ✅ Up to date (5 migrations)
   
   📈 Overall: 2/3 tenants current, 2 migrations pending
   ```

The migrator automatically:
- Runs migrations across all tenant schemas
- Provides detailed progress feedback
- Handles errors gracefully per tenant
- Maintains migration version tracking per schema
- Supports rollbacks for individual tenants

#### Advanced Migration Operations

```bash
# List all tenant schemas
rails tenants:list

# Rollback specific tenant
rails tenants:rollback[tenant_name,2]  # rollback 2 steps

# Drop tenant schema (DANGEROUS - requires confirmation)
rails tenants:drop[old_tenant]
```

#### Programmatic Access

```ruby
# Use the Migrator directly in your code
PgMultitenantSchemas::Migrator.migrate_all
PgMultitenantSchemas::Migrator.setup_tenant('new_client')
PgMultitenantSchemas::Migrator.migration_status
```

### Tenant Resolution

```ruby
# Extract tenant from subdomain
subdomain = PgMultitenantSchemas.extract_subdomain('acme.myapp.com')
# => 'acme'

# Find tenant by subdomain
tenant = PgMultitenantSchemas.find_tenant_by_subdomain('acme')

# Resolve tenant from Rails request
tenant = PgMultitenantSchemas.resolve_tenant_from_request(request)
```

### Context Management

```ruby
# Switch to tenant context
PgMultitenantSchemas.switch_to_tenant(tenant)

# Use block-based context switching
PgMultitenantSchemas.with_tenant(tenant) do
  # All queries here use tenant's schema
  User.all  # Queries tenant_123.users
end

# Check current context
PgMultitenantSchemas.current_tenant
PgMultitenantSchemas.current_schema
```

### Rails Integration

In your ApplicationController:

```ruby
class ApplicationController < ActionController::Base
  include PgMultitenantSchemas::Rails::ControllerConcern
  
  before_action :resolve_tenant
  
  private
  
  def resolve_tenant
    tenant = resolve_tenant_from_subdomain
    switch_to_tenant(tenant) if tenant
  end
end
```

In your models:

```ruby
class Tenant < ApplicationRecord
  include PgMultitenantSchemas::Rails::ModelConcern
  
  after_create :create_tenant_schema
  after_destroy :drop_tenant_schema
end
```

## 🏗️ Multi-Tenant Architecture Principles

### Core Principle: Tenant Isolation

**In well-designed multi-tenant applications, tenants should NOT communicate with each other directly.** Each tenant operates in complete isolation for security, compliance, and data integrity.

```ruby
# ✅ GOOD: Isolated tenant operations
PgMultitenantSchemas.with_tenant(tenant) do
  # All operations are isolated to this tenant's schema
  User.create!(name: "John", email: "john@example.com")
  Order.where(status: "pending").update_all(status: "processed")
end

# ❌ BAD: Cross-tenant data sharing (security risk!)
# Never do: tenant_a.users.merge(tenant_b.users)
```

### When Cross-Schema Operations Are Appropriate

There are only **3 legitimate use cases** for cross-schema operations:

#### 1. **Platform Analytics & Reporting** (Admin-only)
```ruby
# Platform owner needs aggregate statistics across all tenants
def platform_analytics
  PgMultitenantSchemas::SchemaSwitcher.with_connection do |conn|
    conn.execute(<<~SQL)
      SELECT 
        schemaname as tenant,
        COUNT(*) as total_users,
        SUM(revenue) as total_revenue
      FROM (
        SELECT 'tenant_a' as schemaname, COUNT(*) as users, 
               (SELECT SUM(amount) FROM tenant_a.orders) as revenue
        UNION ALL
        SELECT 'tenant_b' as schemaname, COUNT(*) as users,
               (SELECT SUM(amount) FROM tenant_b.orders) as revenue
      ) stats
      GROUP BY schemaname;
    SQL
  end
end
```

#### 2. **Tenant Migration & Data Operations** (Admin-only)
```ruby
# Moving data between environments or consolidating tenants
def migrate_tenant_data(from_tenant, to_tenant)
  PgMultitenantSchemas.with_tenant(from_tenant) do
    users = User.all.to_a
  end
  
  PgMultitenantSchemas.with_tenant(to_tenant) do
    users.each { |user| User.create!(user.attributes.except('id')) }
  end
end
```

#### 3. **Shared Reference Data** (Read-only)
```ruby
# Shared lookup tables that all tenants can read (e.g., countries, currencies)
class Country < ApplicationRecord
  self.table_name = 'public.countries'  # Shared across all schemas
end

# In tenant context, can still access shared data
PgMultitenantSchemas.with_tenant(tenant) do
  user = User.create!(name: "John", country: Country.find_by(code: 'US'))
end
```

### 🚫 Anti-Patterns to Avoid

```ruby
# ❌ NEVER: Direct tenant-to-tenant communication
def share_data_between_tenants(tenant_a, tenant_b)
  # This violates tenant isolation!
end

# ❌ NEVER: Cross-tenant user authentication
def authenticate_user_across_tenants(email)
  # Users should only exist in their tenant's schema
end

# ❌ NEVER: Cross-tenant business logic
def process_order_with_other_tenant_data(order_id, other_tenant)
  # Business logic should be isolated per tenant
end
```

### Why Tenant Isolation Matters

1. **Security**: Prevents accidental data leaks between customers
2. **Compliance**: GDPR, HIPAA, SOX require strict data separation  
3. **Performance**: Each tenant's queries are optimized for their data size
4. **Reliability**: One tenant's issues don't affect others
5. **Scalability**: Easy to move tenants to different database servers

### Architecture Recommendation

```ruby
# ✅ Proper multi-tenant architecture
class ApplicationController < ActionController::Base
  include PgMultitenantSchemas::Rails::ControllerConcern
  
  before_action :authenticate_user!
  before_action :resolve_tenant
  before_action :ensure_user_belongs_to_tenant
  
  private
  
  def resolve_tenant
    @tenant = resolve_tenant_from_subdomain
    switch_to_tenant(@tenant) if @tenant
  end
  
  def ensure_user_belongs_to_tenant
    # Ensure current user can only access their tenant's data
    redirect_to_login unless current_user.tenant == @tenant
  end
end
```

**Bottom Line**: Cross-tenant operations should be **extremely rare**, **admin-only**, and **carefully audited**. The vast majority of your application should operate within a single tenant's schema.

## 📚 Documentation

### Complete Architecture Documentation

Detailed documentation for each core component:

- **[📁 Core Architecture Overview](docs/README.md)** - Complete system architecture
- **[🔧 Schema Switcher](docs/schema_switcher.md)** - Low-level PostgreSQL schema operations
- **[🧵 Context Management](docs/context.md)** - Thread-safe tenant context handling
- **[🚀 Migration System](docs/migrator.md)** - Automated migration management
- **[⚙️ Configuration](docs/configuration.md)** - Gem settings and customization
- **[🔍 Tenant Resolver](docs/tenant_resolver.md)** - Tenant identification strategies
- **[🛤️ Rails Integration](docs/rails_integration.md)** - Framework components and patterns
- **[🚨 Error Handling](docs/errors.md)** - Exception classes and error management

### Examples and Patterns

- **[Schema Operations](examples/schema_operations.rb)** - Core schema management
- **[Context Management](examples/context_management.rb)** - Thread-safe tenant switching
- **[Migration Workflow](examples/migration_workflow.rb)** - Automated migration examples
- **[Rails Controllers](examples/rails_integration/controller_examples.rb)** - Framework integration patterns

## 🧪 Testing

This gem includes a comprehensive test suite with both unit and integration tests.

### Running Tests

```bash
# Run unit tests only (fast, no database required)
bundle exec rspec

# Run integration tests (requires PostgreSQL)
bundle exec rspec --tag integration

# Run all tests
bundle exec rspec --no-tag
```

### Test Categories

- **Unit Tests** (65 examples): Fast, isolated component testing
- **Integration Tests** (21 examples): Real PostgreSQL multi-schema operations
- **Performance Tests**: Memory usage and thread safety validation
- **Edge Cases**: Error handling and boundary condition testing

See [Testing Guide](docs/testing.md) for detailed information about the test suite and [Integration Testing Guide](docs/integration_testing.md) for PostgreSQL integration testing details.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pg_multitenant_schemas. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/pg_multitenant_schemas/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PgMultitenantSchemas project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/pg_multitenant_schemas/blob/main/CODE_OF_CONDUCT.md).
