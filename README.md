# PgMultitenantSchemas

[![Gem Version](https://badge.fury.io/rb/pg_multitenant_schemas.svg)](https://badge.fury.io/rb/pg_multitenant_schemas)
[![Ruby](https://github.com/yourusername/pg_multitenant_schemas/actions/workflows/main.yml/badge.svg)](https://github.com/yourusername/pg_multitenant_schemas/actions/workflows/main.yml)

A Ruby gem that provides PostgreSQL schema-based multitenancy with automatic tenant resolution, schema switching, and Rails integration. Perfect for SaaS applications that need secure tenant isolation.

## Features

- 🏢 **Schema-based multitenancy** - Complete tenant isolation using PostgreSQL schemas
- 🔄 **Automatic schema switching** - Seamlessly switch between tenant schemas
- 🌐 **Subdomain resolution** - Extract tenant from request subdomains
- 🛡️ **Rails 8 compatible** - Works with Rails 7.x and 8.x
- 🚀 **Dual API support** - Backward compatible API design
- 🧵 **Thread-safe** - Safe for concurrent operations
- 📝 **Comprehensive logging** - Track schema operations
- ⚡ **High performance** - Minimal overhead

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

### Basic Schema Operations

```ruby
# Switch to a tenant schema
PgMultitenantSchemas::SchemaSwitcher.switch_schema('tenant_123')

# Create a new schema
PgMultitenantSchemas::SchemaSwitcher.create_schema('tenant_456')

# Check if schema exists
PgMultitenantSchemas::SchemaSwitcher.schema_exists?('tenant_123')

# Drop a schema
PgMultitenantSchemas::SchemaSwitcher.drop_schema('tenant_456')
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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pg_multitenant_schemas. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/pg_multitenant_schemas/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the PgMultitenantSchemas project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/pg_multitenant_schemas/blob/main/CODE_OF_CONDUCT.md).
