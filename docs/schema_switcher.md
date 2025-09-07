# Schema Switcher - Core PostgreSQL Operations

**File**: `lib/pg_multitenant_schemas/schema_switcher.rb`

## 📋 Overview

The `SchemaSwitcher` is the foundation of the multitenancy system, providing low-level PostgreSQL schema operations. It handles the actual database schema switching, creation, and management.

## 🎯 Purpose

- **Schema Switching**: Changes the PostgreSQL search path to target specific tenant schemas
- **Schema Management**: Creates, drops, and manages PostgreSQL schemas
- **Connection Handling**: Works with both Rails connections and raw PG connections
- **SQL Execution**: Provides safe SQL execution within schema contexts

## 🔧 Key Methods

### Core Operations

```ruby
# Switch to a specific schema
SchemaSwitcher.switch_schema(schema_name)

# Create a new schema
SchemaSwitcher.create_schema(schema_name)

# Drop an existing schema
SchemaSwitcher.drop_schema(schema_name, cascade: true)

# Execute SQL in current schema context
SchemaSwitcher.execute_sql(sql_statement)
```

### Schema Introspection

```ruby
# Check if schema exists
SchemaSwitcher.schema_exists?(schema_name)

# Get current schema name
SchemaSwitcher.current_schema

# List all schemas
SchemaSwitcher.list_schemas
```

## 🏗️ Implementation Details

### Connection Management

The SchemaSwitcher works with multiple connection types:

- **Rails ActiveRecord**: Uses `ActiveRecord::Base.connection`
- **Raw PG Connection**: Direct PostgreSQL connections
- **Connection Pooling**: Thread-safe connection handling

### Schema Path Management

PostgreSQL uses a search path to determine schema precedence:

```sql
-- Default search path
SET search_path TO tenant_schema, public;

-- This allows:
-- 1. Tenant-specific tables in tenant_schema
-- 2. Fallback to shared tables in public schema
```

### Error Handling

The SchemaSwitcher provides robust error handling:

- **Invalid Schema Names**: Validates schema name format
- **Connection Errors**: Handles database connection issues
- **Permission Errors**: Manages PostgreSQL permission problems
- **Transaction Safety**: Ensures schema switches are transaction-safe

## 🔄 Usage Patterns

### Basic Schema Switching

```ruby
# Switch to tenant schema
PgMultitenantSchemas::SchemaSwitcher.switch_schema('acme_corp')

# Execute queries - now in acme_corp schema
User.all  # Queries acme_corp.users table

# Switch back to public
PgMultitenantSchemas::SchemaSwitcher.switch_schema('public')
```

### Schema Creation Workflow

```ruby
# Create new tenant schema
schema_name = 'new_tenant'
PgMultitenantSchemas::SchemaSwitcher.create_schema(schema_name)

# Switch to new schema
PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema_name)

# Run migrations in new schema
ActiveRecord::Tasks::DatabaseTasks.migrate
```

### Safe SQL Execution

```ruby
# Execute custom SQL in current schema
sql = "CREATE INDEX CONCURRENTLY idx_users_email ON users(email);"
PgMultitenantSchemas::SchemaSwitcher.execute_sql(sql)
```

## ⚙️ Configuration

The SchemaSwitcher respects global configuration:

```ruby
PgMultitenantSchemas.configure do |config|
  config.default_schema = 'public'
  config.connection_class = 'ApplicationRecord'
end
```

## 🚨 Important Considerations

### Thread Safety

- Schema switching is **per-connection**
- Each thread maintains its own schema context
- Connection pooling ensures thread isolation

### Transaction Behavior

- Schema switches are **not transactional**
- Schema changes persist beyond transaction boundaries
- Always restore previous schema in ensure blocks

### Performance

- Schema switching is fast (single SQL command)
- No data copying or migration required
- Minimal overhead for tenant switching

## 🔍 Debugging

### Check Current Schema

```ruby
current = PgMultitenantSchemas::SchemaSwitcher.current_schema
puts "Currently in schema: #{current}"
```

### Verify Schema Exists

```ruby
if PgMultitenantSchemas::SchemaSwitcher.schema_exists?('tenant_name')
  puts "Schema exists"
else
  puts "Schema not found"
end
```

### List All Schemas

```ruby
schemas = PgMultitenantSchemas::SchemaSwitcher.list_schemas
puts "Available schemas: #{schemas.join(', ')}"
```

## 🔗 Related Components

- **[Context](context.md)**: High-level tenant context management
- **[Migrator](migrator.md)**: Migration management using SchemaSwitcher
- **[Configuration](configuration.md)**: SchemaSwitcher configuration options
- **[Errors](errors.md)**: Schema-related error handling

## 📝 Examples

See [examples/schema_operations.rb](../examples/) for complete usage examples.
