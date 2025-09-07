#!/usr/bin/env ruby
# frozen_string_literal: true

# Example script demonstrating the new migration workflow
# This shows how the simplified migration system works

require_relative "../lib/pg_multitenant_schemas"

puts "🚀 PG Multitenant Schemas - Migration Workflow Example"
puts "======================================================"

# Example 1: Setup new tenant with full migration
puts "\n📋 Example 1: Setting up a new tenant"
puts "Command: PgMultitenantSchemas::Migrator.setup_tenant('example_corp')"
puts "Result: Creates schema + runs all migrations automatically"

# Example 2: Migration status check
puts "\n📊 Example 2: Checking migration status"
puts "Command: PgMultitenantSchemas::Migrator.migration_status"
puts "Result: Shows status across all tenant schemas"

# Example 3: Bulk migration
puts "\n🔄 Example 3: Migrate all tenants"
puts "Command: PgMultitenantSchemas::Migrator.migrate_all"
puts "Result: Runs pending migrations across all tenant schemas"

# Example 4: Individual tenant migration
puts "\n🎯 Example 4: Migrate specific tenant"
puts "Command: PgMultitenantSchemas::Migrator.migrate_tenant('acme_corp')"
puts "Result: Runs migrations only for acme_corp schema"

# Example 5: Create tenant with attributes
puts "\n🏢 Example 5: Create tenant with attributes"
puts "Command: PgMultitenantSchemas::Migrator.create_tenant_with_schema({subdomain: 'newco', name: 'New Company'})"
puts "Result: Creates Tenant record + schema + runs migrations"

puts "\n✨ Key Benefits:"
puts "  • Single command migration across all tenants"
puts "  • Automatic error handling per tenant"
puts "  • Progress tracking and status reporting"
puts "  • Simplified rake task interface"
puts "  • Programmatic API for custom workflows"

puts "\n🔧 Rake Task Examples:"
puts "  rails tenants:migrate          # Migrate all tenants"
puts "  rails tenants:create[newco]    # Setup new tenant"
puts "  rails tenants:status           # Check migration status"
puts "  rails tenants:list             # List all tenant schemas"

puts "\n📖 See README.md for complete documentation"
