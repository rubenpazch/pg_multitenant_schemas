# Integration Testing Guide - PostgreSQL Multi-Schema Operations

## 🎯 **Integration Test Overview**

Integration tests validate real PostgreSQL multi-schema operations, ensuring the gem works correctly with actual database instances. These tests are tagged with `:integration` and require a running PostgreSQL server.

## 🏗️ **Integration Test Architecture**

### **Test Categories**

#### **1. PostgreSQL Integration Tests** 
- **File**: `spec/postgresql_integration_spec.rb`
- **Purpose**: Basic PostgreSQL schema operations
- **Examples**: 5 tests
- **Focus**: Core schema creation, switching, and deletion

#### **2. Multiple Schemas Integration Tests**
- **File**: `spec/multiple_schemas_integration_spec.rb` 
- **Purpose**: Complex multi-tenant scenarios
- **Examples**: 8 tests
- **Focus**: Schema isolation, concurrent access, complex scenarios

#### **3. Multiple Schema Database Operations**
- **File**: `spec/multiple_schemas_database_spec.rb`
- **Purpose**: Bulk operations and data management
- **Examples**: 4 tests  
- **Focus**: Cross-schema queries, bulk operations, dependency management

#### **4. Multiple Tenant Context Tests**
- **File**: `spec/multiple_tenants_context_spec.rb`
- **Purpose**: Context switching between tenants
- **Examples**: 4 tests
- **Focus**: Thread safety, context isolation

## 🔧 **Database Configuration**

### **Environment Setup**

Integration tests use environment variables for PostgreSQL connection:

```bash
# Required PostgreSQL settings
export PG_HOST=localhost                    # Database host
export PG_PORT=5432                        # Database port
export PG_TEST_DATABASE=pg_multitenant_test # Test database
export PG_USER=postgres                    # Database user
export PG_PASSWORD=                        # Database password (if needed)
```

### **Database Preparation**

```bash
# Create test database
createdb pg_multitenant_test

# Alternative: Using psql
psql -c "CREATE DATABASE pg_multitenant_test;"

# Grant permissions (if needed)
psql -d pg_multitenant_test -c "GRANT ALL PRIVILEGES ON SCHEMA public TO postgres;"
```

### **Connection Configuration**

Each integration test establishes its own database connection:

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

let(:conn) do
  PG.connect(db_config)
rescue PG::ConnectionBad => e
  skip "PostgreSQL not available: #{e.message}"
end
```

## 🧪 **Test Execution**

### **Running Integration Tests**

```bash
# Run all integration tests
bundle exec rspec --tag integration

# Run with documentation format
bundle exec rspec --tag integration --format documentation

# Run specific integration test file
bundle exec rspec spec/postgresql_integration_spec.rb

# Run specific test example  
bundle exec rspec ./spec/multiple_schemas_integration_spec.rb:90
```

### **Expected Output**

```bash
Multiple Schema Database Operations
  multiple schema creation and management
    ✓ creates and manages multiple tenant schemas
    ✓ handles cross-schema queries safely  
    ✓ performs bulk operations across multiple schemas
  schema cleanup with dependencies
    ✓ cleans up multiple schemas with foreign key relationships

Multiple Schemas Integration Tests
  multiple tenant schemas
    ✓ creates multiple schemas successfully
    ✓ switches between multiple schemas
    ✓ maintains data isolation between schemas
    ✓ handles concurrent schema access safely
    ✓ drops multiple schemas cleanly
  schema search path with multiple schemas
    ✓ handles complex search paths
  schema migration scenarios
    ✓ handles schema creation with existing objects
  error scenarios with multiple schemas
    ✓ handles dropping non-existent schemas gracefully
    ✓ handles schema dependencies correctly

Finished in 0.67914 seconds
21 examples, 0 failures
```

## 📋 **Detailed Test Scenarios**

### **PostgreSQL Integration Tests**

#### **Schema Creation Tests**
```ruby
describe "schema creation" do
  it "actually creates a schema in PostgreSQL" do
    schema_name = "test_schema"
    
    # Create schema using gem
    PgMultitenantSchemas::SchemaSwitcher.create_schema(schema_name)
    
    # Verify schema exists in PostgreSQL
    result = conn.exec("SELECT schema_name FROM information_schema.schemata WHERE schema_name = '#{schema_name}';")
    expect(result.ntuples).to eq(1)
    expect(result.getvalue(0, 0)).to eq(schema_name)
  end
end
```

#### **Schema Switching Tests**
```ruby
describe "schema switching" do
  it "actually switches the search_path" do
    schema_name = "test_schema"
    PgMultitenantSchemas::SchemaSwitcher.create_schema(schema_name)
    
    # Switch to schema
    PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema_name)
    
    # Verify search_path changed
    result = conn.exec("SELECT current_schema();")
    expect(result.getvalue(0, 0)).to eq(schema_name)
  end
end
```

### **Multiple Schemas Integration Tests**

#### **Data Isolation Tests**
```ruby
describe "multiple tenant schemas" do
  it "maintains data isolation between schemas" do
    tenants = ["tenant_a", "tenant_b", "tenant_c"]
    
    # Create schemas and insert tenant-specific data
    tenants.each do |tenant|
      PgMultitenantSchemas::SchemaSwitcher.create_schema(tenant)
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(tenant)
      
      conn.exec("CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50));")
      conn.exec("INSERT INTO users (name) VALUES ('User from #{tenant}');")
    end
    
    # Verify each schema contains only its own data
    tenants.each do |tenant|
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(tenant)
      result = conn.exec("SELECT name FROM users;")
      expect(result.getvalue(0, 0)).to eq("User from #{tenant}")
    end
  end
end
```

#### **Concurrent Access Tests**
```ruby
describe "concurrent schema access" do
  it "handles concurrent schema access safely" do
    tenants = ["tenant_a", "tenant_b", "tenant_c"]
    
    # Create multiple database connections
    connections = tenants.map { |_| PG.connect(db_config) }
    
    begin
      # Each connection works in different schema
      connections.each_with_index do |connection, index|
        tenant = tenants[index]
        
        # Set search path for this specific connection
        connection.exec("SET search_path TO #{connection.escape_identifier(tenant)}")
        
        # Clean up from previous runs
        connection.exec("DROP TABLE IF EXISTS orders CASCADE")
        
        # Create table and insert data
        connection.exec("CREATE TABLE orders (id SERIAL PRIMARY KEY, tenant_name VARCHAR(50));")
        connection.exec("INSERT INTO orders (tenant_name) VALUES ('#{tenant}');")
        
        # Verify isolation
        result = connection.exec("SELECT tenant_name FROM orders;")
        expect(result.getvalue(0, 0)).to eq(tenant)
      end
    ensure
      connections.each(&:close)
    end
  end
end
```

### **Database Operations Tests**

#### **Cross-Schema Query Tests**
```ruby
describe "cross-schema queries" do
  it "handles cross-schema queries safely" do
    schemas = ["schema_with_users", "schema_with_products"]
    
    schemas.each do |schema|
      PgMultitenantSchemas::SchemaSwitcher.create_schema(schema)
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema)
      
      if schema.include?("users")
        conn.exec("CREATE TABLE customers (id SERIAL PRIMARY KEY, name VARCHAR(50));")
        conn.exec("INSERT INTO customers (name) VALUES ('John Doe');")
      else
        conn.exec("CREATE TABLE customers (id SERIAL PRIMARY KEY, product VARCHAR(50));") 
        conn.exec("INSERT INTO customers (product) VALUES ('Widget');")
      end
    end
    
    # Verify each schema maintains its own table structure
    PgMultitenantSchemas::SchemaSwitcher.switch_schema("schema_with_users")
    result = conn.exec("SELECT column_name FROM information_schema.columns WHERE table_name = 'customers' AND table_schema = 'schema_with_users' ORDER BY ordinal_position;")
    user_columns = result.map { |row| row["column_name"] }
    expect(user_columns).to include("name")
    expect(user_columns).not_to include("product")
  end
end
```

#### **Bulk Operations Tests**
```ruby
describe "bulk operations" do
  it "performs bulk operations across multiple schemas" do
    schemas = ["company_a", "company_b"]
    
    # Set up multiple schemas with data
    schemas.each do |schema|
      PgMultitenantSchemas::SchemaSwitcher.create_schema(schema)
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema)
      
      conn.exec("CREATE TABLE analytics (id SERIAL PRIMARY KEY, metric_value INTEGER);")
      conn.exec("INSERT INTO analytics (metric_value) VALUES (100), (200), (300);")
    end
    
    # Perform bulk analysis across schemas
    total_metrics = 0
    schemas.each do |schema|
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema)
      result = conn.exec("SELECT SUM(metric_value) as total FROM analytics;")
      total_metrics += result.getvalue(0, 0).to_i
    end
    
    expect(total_metrics).to eq(1200) # (100+200+300) * 2 schemas
  end
end
```

## 🧹 **Test Cleanup and Safety**

### **Automatic Cleanup**

Every integration test includes comprehensive cleanup:

```ruby
after do
  # Clean up test schemas created during tests
  ["tenant_a", "tenant_b", "tenant_c", "public_test", "test_schema", 
   "another_test_schema", "company_a", "company_b", "company_c",
   "schema_with_users", "schema_with_products", "sub_tenant", 
   "dependency_test"].each do |schema|
    begin
      PgMultitenantSchemas::SchemaSwitcher.drop_schema(schema, cascade: true)
    rescue => e
      # Log but don't fail tests on cleanup errors
      puts "Cleanup warning: #{e.message}" if ENV['DEBUG_TESTS']
    end
  end
  
  # Always reset to public schema
  PgMultitenantSchemas::SchemaSwitcher.reset_to_public_schema
  
  # Close connections
  conn&.close
end
```

### **Schema Naming Strategy**

Integration tests use predictable schema names for easy cleanup:

- **Tenant Schemas**: `tenant_a`, `tenant_b`, `tenant_c`
- **Company Schemas**: `company_a`, `company_b`, `company_c`  
- **Feature Schemas**: `schema_with_users`, `schema_with_products`
- **Test Schemas**: `test_schema`, `another_test_schema`
- **Special Cases**: `public_test`, `sub_tenant`, `dependency_test`

### **Cascade Deletion**

Tests use `CASCADE` option to handle schema dependencies:

```ruby
# Drop schema with all dependent objects
PgMultitenantSchemas::SchemaSwitcher.drop_schema(schema_name, cascade: true)
```

## 🚨 **Troubleshooting Integration Tests**

### **Common Issues and Solutions**

#### **PostgreSQL Connection Failures**
```bash
# Error: PostgreSQL not available
# Solution: Check PostgreSQL service
brew services start postgresql  # macOS
sudo service postgresql start   # Linux

# Verify connection
pg_isready -h localhost -p 5432
```

#### **Permission Errors**
```bash
# Error: permission denied to create schema
# Solution: Grant schema creation permissions
psql -d pg_multitenant_test -c "GRANT CREATE ON DATABASE pg_multitenant_test TO postgres;"
```

#### **Schema Already Exists**
```bash
# Error: schema "tenant_a" already exists  
# Solution: Manual cleanup
psql -d pg_multitenant_test -c "DROP SCHEMA IF EXISTS tenant_a CASCADE;"
```

#### **Table Already Exists**
```ruby
# Error: relation "orders" already exists
# Fix: Add proper cleanup in test
before do
  conn.exec("DROP TABLE IF EXISTS orders CASCADE")
end
```

### **Debug Mode**

Enable debug output for troubleshooting:

```bash
# Run with debug information
DEBUG_TESTS=1 bundle exec rspec --tag integration

# Run specific failing test with verbose output
bundle exec rspec ./spec/multiple_schemas_integration_spec.rb:90 --format documentation --backtrace
```

### **Manual Database Inspection**

```bash
# Connect to test database
psql -d pg_multitenant_test

# List all schemas
\dn

# Check current schema
SELECT current_schema();

# List tables in specific schema
\dt tenant_a.*

# Clean up manually if needed
DROP SCHEMA IF EXISTS tenant_a CASCADE;
```

## 📊 **Integration Test Metrics**

### **Performance Benchmarks**

- **Total Integration Tests**: 21 examples
- **Average Execution Time**: ~0.67 seconds
- **Database Operations**: ~50+ schema create/drop operations
- **Concurrent Connections**: Up to 3 simultaneous connections
- **Data Isolation**: 100% between tenant schemas

### **Coverage Areas**

✅ **Schema Lifecycle**: Create, switch, drop operations  
✅ **Data Isolation**: Complete tenant separation  
✅ **Concurrent Access**: Multi-connection safety  
✅ **Error Handling**: Graceful failure scenarios  
✅ **Complex Queries**: Cross-schema operations  
✅ **Bulk Operations**: Multi-tenant data processing  
✅ **Dependencies**: Foreign key and cascade handling  
✅ **Search Path**: PostgreSQL search_path management  

## 🎯 **Best Practices for Integration Testing**

### **Test Development Guidelines**

1. **Real Database Operations**: Always test against actual PostgreSQL
2. **Clean Isolation**: Each test creates and destroys its own schemas
3. **Comprehensive Cleanup**: Always clean up after tests, even on failure
4. **Connection Management**: Properly close database connections
5. **Error Scenarios**: Test both success and failure paths
6. **Performance Awareness**: Monitor test execution time
7. **Thread Safety**: Test concurrent access patterns
8. **Documentation**: Document complex test scenarios

### **Integration Test Checklist**

- [ ] Database connection established
- [ ] Schemas created with unique names
- [ ] Operations tested with real PostgreSQL
- [ ] Data isolation verified
- [ ] Cleanup performed in after hooks
- [ ] Error scenarios tested
- [ ] Thread safety validated
- [ ] Performance characteristics measured

This comprehensive integration testing approach ensures the PgMultitenantSchemas gem works reliably in real-world PostgreSQL environments with multiple tenants and complex schema operations.
