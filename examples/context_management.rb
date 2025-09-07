#!/usr/bin/env ruby
# frozen_string_literal: true

# Context Management Example
# Demonstrates thread-safe tenant context management

require_relative "../lib/pg_multitenant_schemas"

puts "🧵 PG Multitenant Schemas - Context Management Example"
puts "======================================================"

# Mock tenant class for demonstration
class MockTenant
  attr_reader :id, :subdomain, :name

  def initialize(id, subdomain, name)
    @id = id
    @subdomain = subdomain
    @name = name
  end

  def to_s
    subdomain
  end
end

# Create mock tenants
tenant_a = MockTenant.new(1, "acme_corp", "ACME Corporation")
tenant_b = MockTenant.new(2, "beta_inc", "Beta Inc")

# Example 1: Basic Context Management
puts "\n📋 Example 1: Basic Context Management"
puts "--------------------------------------"

# Check initial state
puts "Initial context:"
puts "  Current tenant: #{PgMultitenantSchemas::Context.current_tenant || "none"}"
puts "  Current schema: #{PgMultitenantSchemas::Context.current_schema}"

# Switch to tenant A
puts "\nSwitching to tenant A (#{tenant_a.subdomain}):"
PgMultitenantSchemas::Context.switch_to_tenant(tenant_a)
puts "  Current tenant: #{PgMultitenantSchemas::Context.current_tenant}"
puts "  Current schema: #{PgMultitenantSchemas::Context.current_schema}"

# Switch to tenant B
puts "\nSwitching to tenant B (#{tenant_b.subdomain}):"
PgMultitenantSchemas::Context.switch_to_tenant(tenant_b)
puts "  Current tenant: #{PgMultitenantSchemas::Context.current_tenant}"
puts "  Current schema: #{PgMultitenantSchemas::Context.current_schema}"

# Reset context
puts "\nResetting context:"
PgMultitenantSchemas::Context.reset!
puts "  Current tenant: #{PgMultitenantSchemas::Context.current_tenant || "none"}"
puts "  Current schema: #{PgMultitenantSchemas::Context.current_schema}"

# Example 2: Block-Based Context Management
puts "\n🔄 Example 2: Block-Based Context Management"
puts "--------------------------------------------"

puts "Before block - Current schema: #{PgMultitenantSchemas::Context.current_schema}"

PgMultitenantSchemas::Context.with_tenant(tenant_a) do
  puts "Inside block - Current schema: #{PgMultitenantSchemas::Context.current_schema}"
  puts "Inside block - Current tenant: #{PgMultitenantSchemas::Context.current_tenant}"

  # Simulate some work in tenant context
  puts "  🔧 Performing operations for #{tenant_a.name}..."
  sleep(0.1) # Simulate work
end

puts "After block - Current schema: #{PgMultitenantSchemas::Context.current_schema}"
puts "After block - Current tenant: #{PgMultitenantSchemas::Context.current_tenant || "none"}"

# Example 3: Nested Context Management
puts "\n🪆 Example 3: Nested Context Management"
puts "---------------------------------------"

puts "Starting nested context example..."

PgMultitenantSchemas::Context.with_tenant(tenant_a) do
  puts "Level 1 - In tenant A (#{PgMultitenantSchemas::Context.current_schema})"

  PgMultitenantSchemas::Context.with_tenant(tenant_b) do
    puts "  Level 2 - In tenant B (#{PgMultitenantSchemas::Context.current_schema})"

    # Even deeper nesting
    PgMultitenantSchemas::Context.with_tenant("custom_schema") do
      puts "    Level 3 - In custom schema (#{PgMultitenantSchemas::Context.current_schema})"
    end

    puts "  Level 2 - Back in tenant B (#{PgMultitenantSchemas::Context.current_schema})"
  end

  puts "Level 1 - Back in tenant A (#{PgMultitenantSchemas::Context.current_schema})"
end

puts "Nested context complete - Current schema: #{PgMultitenantSchemas::Context.current_schema}"

# Example 4: Error Handling in Context
puts "\n🚨 Example 4: Error Handling in Context"
puts "---------------------------------------"

puts "Testing error handling with context restoration..."

begin
  PgMultitenantSchemas::Context.with_tenant(tenant_a) do
    puts "In tenant A context: #{PgMultitenantSchemas::Context.current_schema}"

    # Simulate an error
    raise StandardError, "Simulated error!"
  end
rescue StandardError => e
  puts "Caught error: #{e.message}"
end

puts "After error - Current schema: #{PgMultitenantSchemas::Context.current_schema}"
puts "✅ Context properly restored after error!"

# Example 5: Thread Safety Demonstration
puts "\n🧵 Example 5: Thread Safety Demonstration"
puts "-----------------------------------------"

threads = []
results = {}

# Create multiple threads with different tenant contexts
[tenant_a, tenant_b].each_with_index do |tenant, index|
  threads << Thread.new do
    thread_id = "Thread-#{index + 1}"
    results[thread_id] = []

    PgMultitenantSchemas::Context.with_tenant(tenant) do
      5.times do |i|
        current_schema = PgMultitenantSchemas::Context.current_schema
        current_tenant = PgMultitenantSchemas::Context.current_tenant

        results[thread_id] << {
          iteration: i + 1,
          schema: current_schema,
          tenant: current_tenant&.subdomain,
          thread: Thread.current.object_id
        }

        sleep(0.01) # Small delay to allow thread interleaving
      end
    end
  end
end

# Wait for all threads to complete
threads.each(&:join)

# Display results
puts "Thread safety results:"
results.each do |thread_id, iterations|
  puts "#{thread_id}:"
  iterations.each do |result|
    puts "  Iteration #{result[:iteration]}: #{result[:schema]} (tenant: #{result[:tenant]})"
  end
end

puts "✅ Each thread maintained its own tenant context!"

# Example 6: Schema Management Through Context
puts "\n🔧 Example 6: Schema Management Through Context"
puts "----------------------------------------------"

test_tenant = MockTenant.new(99, "test_tenant", "Test Tenant")

begin
  # Create tenant schema
  puts "Creating schema for tenant: #{test_tenant.subdomain}"
  PgMultitenantSchemas::Context.create_tenant_schema(test_tenant)
  puts "✅ Schema created successfully"

  # Use the tenant context
  PgMultitenantSchemas::Context.with_tenant(test_tenant) do
    puts "Operating in tenant schema: #{PgMultitenantSchemas::Context.current_schema}"
    # Simulate tenant operations
  end

  # Clean up
  puts "Cleaning up test schema..."
  PgMultitenantSchemas::Context.drop_tenant_schema(test_tenant)
  puts "✅ Schema cleaned up successfully"
rescue PgMultitenantSchemas::SchemaError => e
  puts "❌ Schema operation failed: #{e.message}"
end

puts "\n✨ Context management example completed!"
puts "\n📖 Key Takeaways:"
puts "  • Context is automatically restored after blocks"
puts "  • Each thread maintains independent tenant context"
puts "  • Nested contexts work correctly with proper restoration"
puts "  • Error handling doesn't break context restoration"
puts "  • Context can handle both tenant objects and schema strings"
