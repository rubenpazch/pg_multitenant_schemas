# 🧪 Testing Rails Tasks in PG Multitenant Schemas

## 🚨 Important: Testing Context

The `rails tenants:list` command only works **within a Rails application** that includes this gem, not in the gem directory itself.

## 🔧 Fixed Issues

✅ **Removed circular dependency** in rake task loading
✅ **Eliminated duplicate task files** (`pg_multitenant_schemas.rake` was identical to `tenant_tasks.rake`)
✅ **Updated railtie** to load all task files properly
✅ **Added missing `list_schemas` method** to `SchemaSwitcher` class
✅ **Fixed Rails 8 migration_context compatibility** - Updated migration handling for Rails 8

## 🚀 How to Test the Rails Tasks

### **Option 1: Create a Test Rails App**

```bash
# Create a new Rails app for testing
rails new test_multitenancy --database=postgresql
cd test_multitenancy

# Add the gem to Gemfile
echo 'gem "pg_multitenant_schemas", path: "/Users/rubenpaz/personal/pg_multitenant_schemas"' >> Gemfile

# Install the gem
bundle install

# Now you can test the tasks
rails tenants:list
rails tenants:status
rails tenants:migrate
```

### **Option 2: Use an Existing Rails App**

```bash
# Navigate to your existing Rails app
cd /Users/rubenpaz/personal/lbyte-security  # or wherever your Rails app is

# Add gem to Gemfile if not already added
# gem "pg_multitenant_schemas", path: "/Users/rubenpaz/personal/pg_multitenant_schemas"

# Install and test
bundle install
rails tenants:list
```

### **Option 3: Test in the Example Directory**

```bash
# If there's a Rails example in the gem
cd /Users/rubenpaz/personal/pg_multitenant_schemas/examples
# Follow instructions in that directory
```

## 📋 Available Tasks

After including the gem in a Rails app, you'll have these tasks:

### **Basic Tasks**
- `rails tenants:list` - List all tenant schemas
- `rails tenants:status` - Show migration status for all tenants  
- `rails tenants:migrate` - Run migrations for all tenant schemas

### **Advanced Tasks**  
- `rails tenants:migrate_tenant[schema_name]` - Run migrations for specific tenant
- `rails tenants:create[schema_name]` - Setup new tenant with schema and migrations
- `rails tenants:setup` - Setup schemas and run migrations for all existing tenants

### **Management Tasks**
- `rails tenants:new[attributes]` - Create new tenant with attributes (JSON format)
- `rails tenants:drop[schema_name]` - Drop tenant schema (DANGEROUS)
- `rails tenants:rollback[schema_name,steps]` - Rollback migrations for a tenant

### **Convenience Aliases**
- `rails tenants:db:create[schema_name]` - Alias for `tenants:create`
- `rails tenants:db:migrate` - Alias for `tenants:migrate`
- `rails tenants:db:status` - Alias for `tenants:status`

### **Legacy Tasks (Deprecated)**
- `rails pg_multitenant_schemas:list_schemas` - Use `tenants:list` instead
- `rails pg_multitenant_schemas:migrate_all` - Use `tenants:migrate` instead

## 🛠️ Troubleshooting

### "Command not found" or "stack level too deep"
- ✅ **Fixed**: Circular dependency in task loading removed
- Make sure you're in a Rails application directory
- Run `bundle install` after adding the gem

### "NoMethodError: undefined method 'list_schemas'"  
- ✅ **Fixed**: Added missing `list_schemas` method to `SchemaSwitcher`
- Update to the latest version of the gem

### "NoMethodError: undefined method 'migration_context'"
- ✅ **Fixed**: Updated migration handling for Rails 8 compatibility
- The gem now properly handles migration context access across Rails versions
- Update to the latest version of the gem

### "No such task"
- Ensure the gem is properly added to your Rails app's Gemfile
- Run `bundle install`
- Check that the gem is loading: `rails runner "puts PgMultitenantSchemas::VERSION"`

### "Environment not loaded"
- The tasks require `:environment`, so they need a proper Rails environment
- Make sure your Rails app's database is configured and accessible

## 🧪 Quick Test

To verify everything works, create a minimal test:

```bash
# In your Rails app directory
rails runner "puts 'Gem loaded: ' + PgMultitenantSchemas::VERSION"
rails tenants:list
```

## 📁 Task File Structure

The gem now has a clean task structure:
- `basic_tasks.rake` - List, status, migrate tasks
- `advanced_tasks.rake` - Advanced tenant management  
- `tenant_tasks.rake` - Management tasks + aliases + legacy compatibility

All are loaded automatically via the Rails railtie when you include the gem in your Rails application.
