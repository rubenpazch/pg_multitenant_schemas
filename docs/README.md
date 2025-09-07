# PG Multitenant Schemas - Core Architecture Documentation

This directory contains detailed documentation for each core component of the PG Multitenant Schemas gem.

## 📁 Core Components Overview

| Component | Purpose | Documentation |
|-----------|---------|---------------|
| **SchemaSwitcher** | Low-level PostgreSQL schema operations | [schema_switcher.md](schema_switcher.md) |
| **Context** | Thread-safe tenant context management | [context.md](context.md) |
| **Migrator** | Automated migration management system | [migrator.md](migrator.md) |
| **Configuration** | Gem configuration and settings | [configuration.md](configuration.md) |
| **TenantResolver** | Tenant identification and resolution | [tenant_resolver.md](tenant_resolver.md) |
| **Rails Integration** | Rails framework integration components | [rails_integration.md](rails_integration.md) |
| **Errors** | Custom exception classes | [errors.md](errors.md) |
| **Testing** | RSpec test suite and testing guide | [testing.md](testing.md) |
| **Integration Testing** | PostgreSQL integration testing guide | [integration_testing.md](integration_testing.md) |

## 🏗️ Architecture Flow

```
HTTP Request
    ↓
TenantResolver (identifies tenant)
    ↓
Context (sets tenant context)
    ↓
SchemaSwitcher (switches PostgreSQL schema)
    ↓
Rails Application (executes in tenant schema)
```

## 🔧 Key Concepts

### Schema-Based Multitenancy
- Each tenant gets their own PostgreSQL schema
- Complete data isolation between tenants
- Shared application code, separate data

### Thread-Safe Context
- Tenant context is stored per thread
- Safe for concurrent requests
- Automatic context restoration

### Automated Migrations
- Single command migrates all tenant schemas
- Error handling per tenant
- Progress tracking and status reporting

## 📖 Getting Started

1. **Read the [Configuration Guide](configuration.md)** to understand setup options
2. **Explore [Schema Switcher](schema_switcher.md)** for core PostgreSQL operations
3. **Learn [Context Management](context.md)** for tenant switching
4. **Master [Migration System](migrator.md)** for database management
5. **Understand [Rails Integration](rails_integration.md)** for framework features
6. **Review [Testing Guide](testing.md)** for development and testing practices

## 🧪 Testing and Development

- **[Testing Guide](testing.md)**: Comprehensive RSpec test suite documentation
- **[Integration Testing](integration_testing.md)**: PostgreSQL integration testing guide
- **Test Execution**: `bundle exec rspec` (unit tests) and `bundle exec rspec --tag integration` (integration tests)

## 🔍 Debug and Troubleshooting

- Check [Errors Documentation](errors.md) for exception handling
- Review [TenantResolver](tenant_resolver.md) for tenant identification issues
- Examine Context state for switching problems
- Use [Testing Guide](testing.md) for debugging test failures

## 📚 Additional Resources

- [Main README](../README.md) - Getting started guide
- [CHANGELOG](../CHANGELOG.md) - Version history
- [Examples](../examples/) - Usage examples
- [Specs](../spec/) - Test suite
