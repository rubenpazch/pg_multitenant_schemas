# RSpec Testing Guide - PgMultitenantSchemas

## 📋 **Overview**

This document provides comprehensive information about the RSpec test suite for the PgMultitenantSchemas gem, including unit tests, integration tests, and testing best practices.

## 🏗️ **Test Architecture**

### **Test Categories**

The test suite is organized into two main categories:

#### **1. Unit Tests** (Fast, Isolated)
- **Location**: `spec/*_spec.rb`
- **Execution**: Default `bundle exec rspec` 
- **Purpose**: Test individual components in isolation
- **Database**: Uses mocked connections where possible
- **Speed**: Very fast (~0.03-0.16 seconds)

#### **2. Integration Tests** (Comprehensive, Database)
- **Location**: Tagged with `:integration`
- **Execution**: `bundle exec rspec --tag integration`
- **Purpose**: Test real PostgreSQL interactions and multi-schema operations
- **Database**: Requires running PostgreSQL instance
- **Speed**: Moderate (~0.67-1.17 seconds)

## ⚙️ **Configuration**

### **RSpec Configuration Files**

#### **`.rspec`**
```plaintext
--format documentation
--color
--require spec_helper
--tag ~integration          # Exclude integration tests by default
```

#### **`spec/spec_helper.rb`**
```ruby
require "rspec"
require "pg_multitenant_schemas"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
```

### **Environment Variables**

Integration tests use these environment variables for PostgreSQL connection:

```bash
PG_HOST=localhost              # PostgreSQL host
PG_PORT=5432                  # PostgreSQL port  
PG_TEST_DATABASE=pg_multitenant_test  # Test database name
PG_USER=postgres              # Database user
PG_PASSWORD=                  # Database password (empty by default)
```

## 🧪 **Test Suite Structure**

### **Unit Tests (65 examples)**

| **Test File** | **Component** | **Purpose** |
|---------------|---------------|-------------|
| `configuration_spec.rb` | Configuration | Test configuration options and validation |
| `context_spec.rb` | Context | Test tenant/schema context management |
| `schema_switcher_spec.rb` | SchemaSwitcher | Test schema operations (mocked) |
| `tenant_resolver_spec.rb` | TenantResolver | Test subdomain extraction and tenant resolution |
| `pg_multitenant_schemas_spec.rb` | Main Module | Test gem version and basic functionality |
| `edge_cases_spec.rb` | Edge Cases | Test error handling and edge cases |
| `performance_spec.rb` | Performance | Test memory usage and thread safety |
| `integration_spec.rb` | Integration | Test component interactions (mocked) |
| `errors_spec.rb` | Error Classes | Test custom error definitions |
| `rails_integration/tenant_spec.rb` | Rails Integration | Test Rails model and validation integration |

### **Integration Tests (21 examples)**

| **Test File** | **Component** | **Purpose** |
|---------------|---------------|-------------|
| `postgresql_integration_spec.rb` | PostgreSQL | Real database schema operations |
| `multiple_schemas_integration_spec.rb` | Multi-Schema | Complex schema interactions and isolation |
| `multiple_schemas_database_spec.rb` | Database Ops | Bulk operations and schema management |
| `multiple_tenants_context_spec.rb` | Context | Multi-tenant context switching |

## 🚀 **Running Tests**

### **Unit Tests Only** (Default, Fast)
```bash
# Run all unit tests (excludes integration)
bundle exec rspec

# Run specific unit test file
bundle exec rspec spec/configuration_spec.rb

# Run with verbose output
bundle exec rspec --format documentation
```

### **Integration Tests Only** (Requires PostgreSQL)
```bash
# Run all integration tests
bundle exec rspec --tag integration

# Run with documentation format
bundle exec rspec --tag integration --format documentation

# Run specific integration test
bundle exec rspec spec/postgresql_integration_spec.rb
```

### **All Tests** (Complete Test Suite)
```bash
# Run both unit and integration tests
bundle exec rspec --tag integration spec/ && bundle exec rspec

# Alternative: Run all tests including integration
bundle exec rspec --no-tag
```

## 🔍 **Test Categories Deep Dive**

### **Unit Tests Details**

#### **Configuration Tests**
```ruby
# Tests configuration object behavior
RSpec.describe PgMultitenantSchemas::Configuration do
  describe "#initialize" do
    it "sets default values"
  end
  
  describe "#connection_class=" do
    it "allows setting connection class"
  end
end
```

#### **Context Management Tests**
```ruby
# Tests tenant/schema context switching
RSpec.describe PgMultitenantSchemas::Context do
  describe ".current_schema" do
    it "defaults to public schema"
  end
  
  describe ".current_tenant=" do
    it "sets the current tenant"
  end
end
```

#### **Edge Cases and Error Handling**
```ruby
# Tests robust error handling
RSpec.describe "Edge Cases and Error Handling" do
  describe "schema name validation" do
    it "handles whitespace-only schema names"
    it "handles special characters in schema names"
    it "handles unicode characters"
  end
end
```

### **Integration Tests Details**

#### **PostgreSQL Integration Tests**
```ruby
# Real database operations
RSpec.describe "PostgreSQL Integration Tests", :integration do
  describe "schema creation" do
    it "actually creates a schema in PostgreSQL"
  end
  
  describe "schema switching" do
    it "actually switches the search_path"
  end
end
```

#### **Multiple Schemas Integration**
```ruby
# Complex multi-tenant scenarios
RSpec.describe "Multiple Schemas Integration Tests", :integration do
  describe "multiple tenant schemas" do
    it "creates multiple schemas successfully"
    it "maintains data isolation between schemas"
    it "handles concurrent schema access safely"
  end
end
```

## 🛠️ **Database Setup for Integration Tests**

### **Prerequisites**

1. **PostgreSQL Running**: Ensure PostgreSQL is running locally or accessible
2. **Test Database**: Create a test database (usually `pg_multitenant_test`)
3. **Permissions**: Ensure test user has schema creation/deletion permissions

### **Setup Commands**

```bash
# Create test database (PostgreSQL)
createdb pg_multitenant_test

# Or using psql
psql -c "CREATE DATABASE pg_multitenant_test;"

# Grant necessary permissions
psql -d pg_multitenant_test -c "GRANT ALL PRIVILEGES ON DATABASE pg_multitenant_test TO postgres;"
```

### **Connection Configuration**

Integration tests automatically handle connection setup:

```ruby
let(:db_config) do
  {
    host: ENV["PG_HOST"] || "localhost",
    port: ENV["PG_PORT"] || 5432,
    dbname: ENV["PG_TEST_DATABASE"] || "pg_multitenant_test",
    user: ENV["PG_USER"] || "postgres",
    password: ENV["PG_PASSWORD"] || ""
  }
end
```

## 🧹 **Test Cleanup and Isolation**

### **Automatic Cleanup**

Integration tests include comprehensive cleanup:

```ruby
after do
  # Clean up test schemas
  ["tenant_a", "tenant_b", "tenant_c", "public_test"].each do |schema|
    PgMultitenantSchemas::SchemaSwitcher.drop_schema(schema, cascade: true)
  rescue => e
    # Log cleanup errors but don't fail tests
  end
  
  # Reset to public schema
  PgMultitenantSchemas::SchemaSwitcher.reset_to_public_schema
end
```

### **Schema Isolation**

Each test creates and destroys its own schemas:

```ruby
let(:tenants) { ["tenant_a", "tenant_b", "tenant_c"] }

before do
  # Ensure clean state
  tenants.each { |t| PgMultitenantSchemas::SchemaSwitcher.create_schema(t) }
end
```

## 📊 **Test Coverage and Quality**

### **Current Test Metrics**

- **Total Examples**: 86 (65 unit + 21 integration)
- **Failures**: 0
- **Coverage Areas**:
  - ✅ Configuration management
  - ✅ Schema operations  
  - ✅ Tenant resolution
  - ✅ Context switching
  - ✅ Error handling
  - ✅ Performance characteristics
  - ✅ Thread safety
  - ✅ Rails integration
  - ✅ Multi-schema scenarios
  - ✅ Concurrent access patterns

### **Test Quality Features**

- **Fast Unit Tests**: Complete in ~0.03 seconds
- **Comprehensive Integration**: Real PostgreSQL testing
- **Thread Safety**: Multi-threaded scenario testing
- **Memory Leak Detection**: Performance monitoring
- **Edge Case Coverage**: Unicode, special characters, malformed data
- **Error Scenario Testing**: Connection failures, invalid schemas

## 🔧 **Debugging Tests**

### **Common Issues and Solutions**

#### **PostgreSQL Connection Issues**
```bash
# Check if PostgreSQL is running
pg_isready

# Check connection with custom settings
PG_HOST=localhost PG_USER=myuser bundle exec rspec --tag integration
```

#### **Schema Cleanup Issues**
```ruby
# Manual cleanup if tests leave artifacts
psql -d pg_multitenant_test -c "DROP SCHEMA IF EXISTS tenant_a CASCADE;"
```

#### **Verbose Test Output**
```bash
# Run with detailed output for debugging
bundle exec rspec --format documentation --color

# Run specific failing test
bundle exec rspec spec/multiple_schemas_integration_spec.rb:90 --format documentation
```

### **Test Development Tips**

1. **Unit Test First**: Write fast unit tests before integration tests
2. **Mock External Dependencies**: Use mocks for database connections in unit tests
3. **Clean Isolation**: Ensure each test cleans up after itself
4. **Descriptive Names**: Use clear, descriptive test names
5. **Edge Cases**: Test boundary conditions and error scenarios

## 📚 **Related Documentation**

- **[Architecture Overview](README.md)**: Understanding the overall gem structure
- **[Configuration Guide](configuration.md)**: Test configuration options
- **[Rails Integration](rails_integration.md)**: Framework-specific testing patterns
- **[Error Handling](errors.md)**: Error testing strategies

## 🎯 **Test Development Workflow**

### **Adding New Tests**

1. **Identify Test Type**: Unit vs Integration
2. **Create Test File**: Follow naming convention `*_spec.rb`
3. **Add Appropriate Tags**: Use `:integration` for database tests
4. **Include Setup/Teardown**: Proper before/after hooks
5. **Test Edge Cases**: Include error scenarios
6. **Run Test Suite**: Verify no regressions

### **Best Practices**

- **Keep Unit Tests Fast**: Avoid database calls in unit tests
- **Use Descriptive Contexts**: Group related tests logically  
- **Test Public APIs**: Focus on public interface testing
- **Mock External Services**: Isolate component under test
- **Include Performance Tests**: Monitor resource usage
- **Document Complex Scenarios**: Comment non-obvious test logic

This comprehensive test suite ensures the PgMultitenantSchemas gem is robust, reliable, and ready for production use across various scenarios and environments.
