# Context - Thread-Safe Tenant Management

**File**: `lib/pg_multitenant_schemas/context.rb`

## 📋 Overview

The `Context` class provides thread-safe tenant context management, maintaining current tenant and schema state across request lifecycle. It's the high-level interface for tenant switching and context management.

## 🎯 Purpose

- **Thread Safety**: Maintains separate tenant context per thread
- **Context Management**: Tracks current tenant and schema state
- **Automatic Restoration**: Ensures context is properly restored after operations
- **High-Level API**: Provides convenient methods for tenant switching

## 🔧 Key Methods

### Current State Management

```ruby
# Get/Set current tenant
Context.current_tenant
Context.current_tenant = tenant_object

# Get/Set current schema
Context.current_schema
Context.current_schema = 'schema_name'

# Reset to default state
Context.reset!
```

### Tenant Switching

```ruby
# Switch to specific tenant
Context.switch_to_tenant(tenant_object)

# Switch to specific schema
Context.switch_to_schema('schema_name')

# Execute block in tenant context
Context.with_tenant(tenant_or_schema) do
  # Code executes in tenant context
  User.all  # Queries tenant's users
end
# Automatically restores previous context
```

### Schema Management

```ruby
# Create tenant schema
Context.create_tenant_schema(tenant_or_schema)

# Drop tenant schema
Context.drop_tenant_schema(tenant_or_schema, cascade: true)
```

## 🏗️ Implementation Details

### Thread-Local Storage

Context uses Ruby's `Thread.current` to store tenant state:

```ruby
def current_tenant
  Thread.current[:pg_multitenant_current_tenant]
end

def current_schema
  Thread.current[:pg_multitenant_current_schema] || 
    PgMultitenantSchemas.configuration.default_schema
end
```

This ensures:
- **Isolation**: Each thread has independent tenant context
- **Concurrency**: Multiple requests can have different tenant contexts
- **Safety**: No cross-request tenant bleeding

### Context Restoration

The `with_tenant` method provides automatic context restoration:

```ruby
def with_tenant(tenant_or_schema)
  # Store current state
  previous_tenant = current_tenant
  previous_schema = current_schema
  
  begin
    # Switch to new context
    switch_to_schema(schema_name)
    self.current_tenant = tenant
    yield if block_given?
  ensure
    # Always restore previous context
    restore_previous_context(previous_tenant, previous_schema)
  end
end
```

### Flexible Input Handling

Context methods accept multiple input types:

- **Tenant Objects**: `tenant.subdomain` is used as schema name
- **String/Symbol**: Used directly as schema name
- **Nil**: Switches to default schema

## 🔄 Usage Patterns

### Basic Tenant Switching

```ruby
# Using tenant object
tenant = Tenant.find_by(subdomain: 'acme')
PgMultitenantSchemas::Context.switch_to_tenant(tenant)

# Using schema name directly
PgMultitenantSchemas::Context.switch_to_schema('acme_corp')

# Check current state
puts PgMultitenantSchemas::Context.current_schema  # => "acme_corp"
```

### Block-Based Context

```ruby
# Execute code in tenant context
PgMultitenantSchemas::Context.with_tenant('acme_corp') do
  # All database operations happen in acme_corp schema
  users = User.all
  orders = Order.where(status: 'pending')
  
  # Create new records in tenant schema
  User.create!(email: 'user@acme.com')
end

# Context automatically restored to previous state
puts PgMultitenantSchemas::Context.current_schema  # => "public"
```

### Nested Contexts

```ruby
# Nested tenant contexts work correctly
PgMultitenantSchemas::Context.with_tenant('tenant_a') do
  puts "In tenant A: #{Context.current_schema}"
  
  PgMultitenantSchemas::Context.with_tenant('tenant_b') do
    puts "In tenant B: #{Context.current_schema}"
  end
  
  puts "Back in tenant A: #{Context.current_schema}"
end
puts "Back in original context: #{Context.current_schema}"
```

### Error Handling

```ruby
# Context is restored even if errors occur
PgMultitenantSchemas::Context.with_tenant('acme_corp') do
  raise "Something went wrong!"
rescue => e
  puts "Error: #{e.message}"
end

# Context is still properly restored
puts PgMultitenantSchemas::Context.current_schema  # => "public"
```

## 🔗 Integration Points

### Controller Integration

```ruby
class ApplicationController < ActionController::Base
  around_action :set_tenant_context
  
  private
  
  def set_tenant_context
    tenant = resolve_tenant_from_request
    PgMultitenantSchemas::Context.with_tenant(tenant) do
      yield
    end
  end
end
```

### Background Jobs

```ruby
class TenantJob < ApplicationJob
  def perform(tenant_id, *args)
    tenant = Tenant.find(tenant_id)
    PgMultitenantSchemas::Context.with_tenant(tenant) do
      # Job executes in tenant context
      process_tenant_data
    end
  end
end
```

### Model Callbacks

```ruby
class Order < ApplicationRecord
  after_create :send_notification
  
  private
  
  def send_notification
    # This runs in the same tenant context as the creation
    current_tenant = PgMultitenantSchemas::Context.current_tenant
    NotificationMailer.order_created(self, current_tenant).deliver_later
  end
end
```

## ⚙️ Configuration

Context behavior is influenced by global configuration:

```ruby
PgMultitenantSchemas.configure do |config|
  config.default_schema = 'public'  # Default context
  config.connection_class = 'ApplicationRecord'
end
```

## 🚨 Important Considerations

### Thread Safety

- **Safe**: Each thread maintains independent context
- **Isolation**: No cross-thread context interference
- **Connection Pools**: Works correctly with Rails connection pooling

### Memory Management

- Context data is cleaned up when threads end
- No memory leaks from tenant context storage
- Minimal memory overhead per thread

### Performance

- Context switching is very fast
- No database queries required for context management
- Minimal CPU and memory overhead

## 🔍 Debugging

### Check Current Context

```ruby
# Current tenant and schema
puts "Tenant: #{PgMultitenantSchemas::Context.current_tenant&.subdomain}"
puts "Schema: #{PgMultitenantSchemas::Context.current_schema}"
```

### Debug Context Stack

```ruby
# Add logging to track context changes
module PgMultitenantSchemas
  class Context
    class << self
      alias_method :original_switch_to_schema, :switch_to_schema
      
      def switch_to_schema(schema_name)
        Rails.logger.debug "Switching to schema: #{schema_name}"
        original_switch_to_schema(schema_name)
      end
    end
  end
end
```

## 🔗 Related Components

- **[SchemaSwitcher](schema_switcher.md)**: Low-level schema operations used by Context
- **[TenantResolver](tenant_resolver.md)**: Identifies tenants for context switching
- **[Rails Integration](rails_integration.md)**: Framework integration using Context
- **[Configuration](configuration.md)**: Context configuration options

## 📝 Examples

See [examples/context_management.rb](../examples/) for complete usage examples.
