# Configuration - Gem Settings and Options

**File**: `lib/pg_multitenant_schemas/configuration.rb`

## 📋 Overview

The `Configuration` class manages all configurable aspects of the PG Multitenant Schemas gem. It provides a centralized way to customize behavior, set defaults, and integrate with different Rails applications.

## 🎯 Purpose

- **Centralized Settings**: Single location for all gem configuration
- **Framework Integration**: Seamless Rails integration options
- **Customization**: Flexible options for different deployment scenarios
- **Defaults Management**: Sensible defaults with override capabilities

## 🔧 Configuration Options

### Core Settings

```ruby
PgMultitenantSchemas.configure do |config|
  # Default schema to use (usually 'public')
  config.default_schema = 'public'
  
  # ActiveRecord connection class
  config.connection_class = 'ApplicationRecord'
  
  # Tenant model class name
  config.tenant_model = 'Tenant'
  
  # Schema naming strategy
  config.schema_prefix = nil  # No prefix by default
end
```

### Connection Management

```ruby
PgMultitenantSchemas.configure do |config|
  # Connection class for database operations
  config.connection_class = 'ApplicationRecord'  # Default
  # config.connection_class = 'TenantRecord'     # Custom connection
  # config.connection_class = 'ReadOnlyRecord'   # Read-only operations
end
```

### Tenant Resolution

```ruby
PgMultitenantSchemas.configure do |config|
  # Model used for tenant lookup
  config.tenant_model = 'Tenant'  # Default
  # config.tenant_model = 'Organization'
  # config.tenant_model = 'Account'
  
  # Attribute used for schema naming
  config.tenant_schema_attribute = :subdomain  # Default
  # config.tenant_schema_attribute = :slug
  # config.tenant_schema_attribute = :code
end
```

### Schema Management

```ruby
PgMultitenantSchemas.configure do |config|
  # Default schema for non-tenant operations
  config.default_schema = 'public'
  
  # Schema naming prefix (optional)
  config.schema_prefix = 'tenant_'  # Results in 'tenant_acme', 'tenant_beta'
  # config.schema_prefix = nil       # Results in 'acme', 'beta'
  
  # Schema exclusion patterns
  config.excluded_schemas = ['information_schema', 'pg_catalog', 'pg_toast']
end
```

## 🏗️ Implementation Details

### Configuration Class Structure

```ruby
module PgMultitenantSchemas
  class Configuration
    attr_accessor :default_schema,
                  :connection_class,
                  :tenant_model,
                  :tenant_schema_attribute,
                  :schema_prefix,
                  :excluded_schemas

    def initialize
      @default_schema = 'public'
      @connection_class = 'ApplicationRecord'
      @tenant_model = 'Tenant'
      @tenant_schema_attribute = :subdomain
      @schema_prefix = nil
      @excluded_schemas = default_excluded_schemas
    end
  end
end
```

### Dynamic Configuration Loading

The configuration supports dynamic loading and environment-specific settings:

```ruby
# Load from environment variables
config.default_schema = ENV['PG_MULTITENANT_DEFAULT_SCHEMA'] || 'public'

# Environment-specific configuration
if Rails.env.development?
  config.schema_prefix = 'dev_'
elsif Rails.env.test?
  config.schema_prefix = 'test_'
end
```

## 🔄 Usage Patterns

### Basic Configuration

```ruby
# config/initializers/pg_multitenant_schemas.rb
PgMultitenantSchemas.configure do |config|
  config.default_schema = 'public'
  config.tenant_model = 'Organization'
  config.connection_class = 'ApplicationRecord'
end
```

### Advanced Configuration

```ruby
# config/initializers/pg_multitenant_schemas.rb
PgMultitenantSchemas.configure do |config|
  # Core settings
  config.default_schema = 'shared'
  config.tenant_model = 'Account'
  config.tenant_schema_attribute = :slug
  
  # Schema naming
  config.schema_prefix = Rails.env.production? ? nil : "#{Rails.env}_"
  
  # Connection management
  config.connection_class = 'TenantRecord'
  
  # Exclusions
  config.excluded_schemas += ['analytics', 'logs']
end
```

### Environment-Specific Configuration

```ruby
# config/initializers/pg_multitenant_schemas.rb
PgMultitenantSchemas.configure do |config|
  case Rails.env
  when 'development'
    config.schema_prefix = 'dev_'
    config.default_schema = 'dev_public'
  when 'test'
    config.schema_prefix = 'test_'
    config.default_schema = 'test_public'
  when 'staging'
    config.schema_prefix = 'staging_'
    config.default_schema = 'public'
  when 'production'
    config.schema_prefix = nil
    config.default_schema = 'public'
  end
end
```

## 🎛️ Configuration Validation

The gem includes configuration validation to catch common issues:

```ruby
def validate_configuration!
  raise ConfigurationError, "tenant_model must be defined" if tenant_model.blank?
  raise ConfigurationError, "default_schema cannot be blank" if default_schema.blank?
  
  # Validate tenant model exists
  begin
    tenant_model.constantize
  rescue NameError
    raise ConfigurationError, "Tenant model '#{tenant_model}' not found"
  end
  
  # Validate connection class
  begin
    connection_class.constantize
  rescue NameError
    raise ConfigurationError, "Connection class '#{connection_class}' not found"
  end
end
```

## 🔧 Integration Examples

### Custom Tenant Models

```ruby
# For custom tenant model structure
class Organization < ApplicationRecord
  has_many :users
  
  def schema_name
    "org_#{slug}"
  end
end

# Configuration
PgMultitenantSchemas.configure do |config|
  config.tenant_model = 'Organization'
  config.tenant_schema_attribute = :schema_name
end
```

### Multiple Database Setup

```ruby
# For applications with multiple databases
class TenantRecord < ApplicationRecord
  connects_to database: { writing: :tenant_primary, reading: :tenant_replica }
end

PgMultitenantSchemas.configure do |config|
  config.connection_class = 'TenantRecord'
end
```

### Custom Schema Naming

```ruby
# Custom schema naming logic
module SchemaNameBuilder
  def self.build_name(tenant)
    case tenant.tier
    when 'enterprise'
      "ent_#{tenant.slug}"
    when 'premium'
      "prem_#{tenant.slug}"
    else
      "std_#{tenant.slug}"
    end
  end
end

PgMultitenantSchemas.configure do |config|
  config.schema_name_builder = SchemaNameBuilder
end
```

## 🚨 Important Considerations

### Configuration Timing

- Configure the gem **before** Rails application initialization
- Place configuration in `config/initializers/`
- Ensure configuration runs before model loading

### Thread Safety

- Configuration is **read-only** after initialization
- Safe to access from multiple threads
- No runtime configuration changes supported

### Performance Impact

- Configuration lookups are fast (cached)
- No database queries for configuration access
- Minimal memory overhead

## 🔍 Configuration Debugging

### Check Current Configuration

```ruby
# Display current configuration
config = PgMultitenantSchemas.configuration
puts "Default Schema: #{config.default_schema}"
puts "Tenant Model: #{config.tenant_model}"
puts "Connection Class: #{config.connection_class}"
puts "Schema Prefix: #{config.schema_prefix}"
```

### Validate Configuration

```ruby
# Validate configuration is correct
begin
  PgMultitenantSchemas.configuration.validate_configuration!
  puts "✅ Configuration is valid"
rescue PgMultitenantSchemas::ConfigurationError => e
  puts "❌ Configuration error: #{e.message}"
end
```

## 🔗 Related Components

- **[Context](context.md)**: Uses configuration for default schema
- **[SchemaSwitcher](schema_switcher.md)**: Uses connection class configuration
- **[TenantResolver](tenant_resolver.md)**: Uses tenant model configuration
- **[Rails Integration](rails_integration.md)**: Framework-specific configuration

## 📝 Configuration Templates

### Standard Rails App
```ruby
PgMultitenantSchemas.configure do |config|
  config.default_schema = 'public'
  config.tenant_model = 'Tenant'
  config.connection_class = 'ApplicationRecord'
end
```

### SaaS Application
```ruby
PgMultitenantSchemas.configure do |config|
  config.default_schema = 'shared'
  config.tenant_model = 'Account'
  config.tenant_schema_attribute = :subdomain
  config.schema_prefix = Rails.env.production? ? nil : "#{Rails.env}_"
end
```

### Enterprise Application
```ruby
PgMultitenantSchemas.configure do |config|
  config.default_schema = 'master'
  config.tenant_model = 'Organization'
  config.tenant_schema_attribute = :schema_name
  config.connection_class = 'TenantRecord'
  config.excluded_schemas += ['audit', 'analytics', 'logs']
end
```
