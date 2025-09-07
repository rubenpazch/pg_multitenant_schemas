#!/usr/bin/env ruby
# frozen_string_literal: true

# Schema Operations Example
# Demonstrates core schema switching and management operations

require_relative "../lib/pg_multitenant_schemas"

puts "🔧 PG Multitenant Schemas - Schema Operations Example"
puts "====================================================="

# Example 1: Basic Schema Switching
puts "\n📋 Example 1: Basic Schema Switching"
puts "------------------------------------"

# Switch to a tenant schema
schema_name = "demo_tenant"
puts "Switching to schema: #{schema_name}"

begin
  PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema_name)
  current = PgMultitenantSchemas::SchemaSwitcher.current_schema
  puts "✅ Current schema: #{current}"
rescue PgMultitenantSchemas::SchemaError => e
  puts "❌ Schema switch failed: #{e.message}"
end

# Example 2: Schema Creation and Management
puts "\n🏗️  Example 2: Schema Creation and Management"
puts "---------------------------------------------"

new_schema = "example_tenant"
puts "Creating schema: #{new_schema}"

begin
  # Create new schema
  PgMultitenantSchemas::SchemaSwitcher.create_schema(new_schema)
  puts "✅ Schema created: #{new_schema}"

  # Verify schema exists
  puts "✅ Schema exists: #{new_schema}" if PgMultitenantSchemas::SchemaSwitcher.schema_exists?(new_schema)

  # List all schemas
  schemas = PgMultitenantSchemas::SchemaSwitcher.list_schemas
  puts "📋 Available schemas: #{schemas.join(", ")}"
rescue PgMultitenantSchemas::SchemaError => e
  puts "❌ Schema operation failed: #{e.message}"
end

# Example 3: Safe Schema Operations
puts "\n🛡️  Example 3: Safe Schema Operations"
puts "------------------------------------"

begin
  # Store current schema
  original_schema = PgMultitenantSchemas::SchemaSwitcher.current_schema
  puts "Original schema: #{original_schema}"

  # Switch to tenant schema
  PgMultitenantSchemas::SchemaSwitcher.switch_schema("demo_tenant")
  puts "Switched to: #{PgMultitenantSchemas::SchemaSwitcher.current_schema}"

  # Execute some operations here...
  puts "Performing tenant-specific operations..."

  # Always restore original schema
  PgMultitenantSchemas::SchemaSwitcher.switch_schema(original_schema)
  puts "✅ Restored to original schema: #{PgMultitenantSchemas::SchemaSwitcher.current_schema}"
rescue PgMultitenantSchemas::SchemaError => e
  puts "❌ Error: #{e.message}"
  # Ensure we restore the original schema even on error
  begin
    PgMultitenantSchemas::SchemaSwitcher.switch_schema(original_schema)
  rescue StandardError
    nil
  end
end

# Example 4: Schema Validation
puts "\n✅ Example 4: Schema Validation"
puts "-------------------------------"

test_schemas = ["valid_schema", "invalid-schema!", "", "another_valid_123"]

test_schemas.each do |schema|
  puts "Testing schema name: '#{schema}'"

  if schema.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/) && !schema.blank?
    puts "  ✅ Valid schema name"

    # Try to create (for demonstration)
    # PgMultitenantSchemas::SchemaSwitcher.create_schema(schema)
  else
    puts "  ❌ Invalid schema name format"
  end
rescue PgMultitenantSchemas::SchemaError => e
  puts "  ❌ Schema error: #{e.message}"
end

# Example 5: Schema Cleanup
puts "\n🧹 Example 5: Schema Cleanup"
puts "----------------------------"

cleanup_schema = "example_tenant"
puts "Cleaning up schema: #{cleanup_schema}"

begin
  if PgMultitenantSchemas::SchemaSwitcher.schema_exists?(cleanup_schema)
    PgMultitenantSchemas::SchemaSwitcher.drop_schema(cleanup_schema)
    puts "✅ Schema dropped: #{cleanup_schema}"
  else
    puts "ℹ️  Schema doesn't exist: #{cleanup_schema}"
  end
rescue PgMultitenantSchemas::SchemaError => e
  puts "❌ Cleanup failed: #{e.message}"
end

puts "\n✨ Schema operations example completed!"
puts "\n📖 Key Takeaways:"
puts "  • Always validate schema names before operations"
puts "  • Use proper error handling for schema operations"
puts "  • Store and restore original schema in ensure blocks"
puts "  • Check schema existence before creation or deletion"
puts "  • Use meaningful schema naming conventions"
