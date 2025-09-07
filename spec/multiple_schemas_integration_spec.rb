# frozen_string_literal: true

require "spec_helper"
require "pg"

RSpec.describe "Multiple Schemas Integration Tests", :integration do
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

  before do
    # Configure the gem to use our test connection
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:connection).and_return(conn)
  end

  after do
    # Clean up all test schemas
    if defined?(conn) && conn
      %w[tenant_a tenant_b tenant_c public_test].each do |schema|
        conn.exec("DROP SCHEMA IF EXISTS #{schema} CASCADE;")
      end
      conn.close
    end
  end

  describe "multiple tenant schemas" do
    let(:tenants) { %w[tenant_a tenant_b tenant_c] }

    it "creates multiple schemas successfully" do
      tenants.each do |tenant|
        PgMultitenantSchemas::SchemaSwitcher.create_schema(tenant)
        expect(PgMultitenantSchemas::SchemaSwitcher.schema_exists?(tenant)).to be true
      end
    end

    it "switches between multiple schemas" do
      # Create all schemas
      tenants.each { |t| PgMultitenantSchemas::SchemaSwitcher.create_schema(t) }

      # Switch between them and verify
      tenants.each do |tenant|
        PgMultitenantSchemas::SchemaSwitcher.switch_schema(tenant)
        current = PgMultitenantSchemas::SchemaSwitcher.current_schema
        expect(current).to eq(tenant)
      end
    end

    it "maintains data isolation between schemas" do
      # Create schemas
      tenants.each { |t| PgMultitenantSchemas::SchemaSwitcher.create_schema(t) }

      # Create tables with different data in each schema
      tenants.each_with_index do |tenant, _index|
        PgMultitenantSchemas::SchemaSwitcher.switch_schema(tenant)

        # Create table
        conn.exec("CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50));")

        # Insert tenant-specific data
        conn.exec("INSERT INTO users (name) VALUES ('User from #{tenant}');")

        # Verify data
        result = conn.exec("SELECT name FROM users;")
        expect(result.getvalue(0, 0)).to eq("User from #{tenant}")
      end

      # Verify isolation - each schema should only see its own data
      tenants.each do |tenant|
        PgMultitenantSchemas::SchemaSwitcher.switch_schema(tenant)
        result = conn.exec("SELECT COUNT(*) FROM users;")
        expect(result.getvalue(0, 0)).to eq("1") # Only one user per schema

        result = conn.exec("SELECT name FROM users;")
        expect(result.getvalue(0, 0)).to eq("User from #{tenant}")
      end
    end

    it "handles concurrent schema access safely" do
      # Create schemas
      tenants.each { |t| PgMultitenantSchemas::SchemaSwitcher.create_schema(t) }

      # Simulate concurrent access with multiple connections
      connections = tenants.map { |_| PG.connect(db_config) }

      begin
        # Each connection works in different schema
        connections.each_with_index do |connection, index|
          tenant = tenants[index]
          PgMultitenantSchemas::SchemaSwitcher.switch_schema(tenant)

          # Create table and insert data
          connection.exec("CREATE TABLE orders (id SERIAL PRIMARY KEY, tenant_name VARCHAR(50));")
          connection.exec("INSERT INTO orders (tenant_name) VALUES ('#{tenant}');")

          # Verify each connection sees only its schema's data
          tenant = tenants[index]
          result = connection.exec("SELECT tenant_name FROM orders;")
          expect(result.getvalue(0, 0)).to eq(tenant)
        end
      ensure
        connections.each(&:close)
      end
    end

    it "drops multiple schemas cleanly" do
      # Create all schemas
      tenants.each { |t| PgMultitenantSchemas::SchemaSwitcher.create_schema(t) }

      # Verify they exist
      tenants.each do |tenant|
        expect(PgMultitenantSchemas::SchemaSwitcher.schema_exists?(tenant)).to be true
      end

      # Drop all schemas
      tenants.each { |t| PgMultitenantSchemas::SchemaSwitcher.drop_schema(t) }

      # Verify they're gone
      tenants.each do |tenant|
        expect(PgMultitenantSchemas::SchemaSwitcher.schema_exists?(tenant)).to be false
      end
    end
  end

  describe "schema search path with multiple schemas" do
    it "handles complex search paths" do
      # Create multiple schemas
      %w[tenant_a tenant_b public].each do |schema|
        PgMultitenantSchemas::SchemaSwitcher.create_schema(schema) unless schema == "public"
      end

      # Set complex search path
      conn.exec('SET search_path TO "tenant_a", "tenant_b", public;')

      # Create table in tenant_a
      PgMultitenantSchemas::SchemaSwitcher.switch_schema("tenant_a")
      conn.exec("CREATE TABLE shared_table (id SERIAL PRIMARY KEY, source VARCHAR(20));")
      conn.exec("INSERT INTO shared_table (source) VALUES ('tenant_a');")

      # Create table in tenant_b
      PgMultitenantSchemas::SchemaSwitcher.switch_schema("tenant_b")
      conn.exec("CREATE TABLE shared_table (id SERIAL PRIMARY KEY, source VARCHAR(20));")
      conn.exec("INSERT INTO shared_table (source) VALUES ('tenant_b');")

      # Test search path priority
      conn.exec('SET search_path TO "tenant_a", "tenant_b", public;')
      result = conn.exec("SELECT source FROM shared_table;")
      expect(result.getvalue(0, 0)).to eq("tenant_a") # Should find tenant_a first
    end
  end

  describe "schema migration scenarios" do
    it "handles schema creation with existing objects" do
      schema_name = "migration_test"

      # Create schema and add objects
      PgMultitenantSchemas::SchemaSwitcher.create_schema(schema_name)
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema_name)

      # Add tables, indexes, functions
      conn.exec(<<~SQL)
        CREATE TABLE products (
          id SERIAL PRIMARY KEY,
          name VARCHAR(100) NOT NULL,
          price DECIMAL(10,2)
        );
        CREATE INDEX idx_products_name ON products(name);
        CREATE OR REPLACE FUNCTION get_product_count() RETURNS INTEGER AS $$
        BEGIN
          RETURN (SELECT COUNT(*) FROM products);
        END;
        $$ LANGUAGE plpgsql;
      SQL

      # Insert test data
      conn.exec("INSERT INTO products (name, price) VALUES ('Product 1', 10.99), ('Product 2', 20.50);")

      # Verify everything works
      result = conn.exec("SELECT get_product_count();")
      expect(result.getvalue(0, 0)).to eq("2")

      # Drop schema with CASCADE should remove everything
      PgMultitenantSchemas::SchemaSwitcher.drop_schema(schema_name, cascade: true)
      expect(PgMultitenantSchemas::SchemaSwitcher.schema_exists?(schema_name)).to be false
    end
  end

  describe "error scenarios with multiple schemas" do
    it "handles dropping non-existent schemas gracefully" do
      expect do
        PgMultitenantSchemas::SchemaSwitcher.drop_schema("nonexistent_schema")
      end.not_to raise_error
    end

    it "handles schema dependencies correctly" do
      schema_name = "dependency_test"

      # Create schema with objects
      PgMultitenantSchemas::SchemaSwitcher.create_schema(schema_name)
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema_name)
      conn.exec("DROP TABLE IF EXISTS test_table;")
      conn.exec("CREATE TABLE test_table (id SERIAL);")

      # Switch back to public
      PgMultitenantSchemas::SchemaSwitcher.switch_schema("public")

      # DROP RESTRICT should fail when schema has dependencies
      expect do
        PgMultitenantSchemas::SchemaSwitcher.drop_schema(schema_name, cascade: false)
      end.to raise_error(PG::DependentObjectsStillExist)

      # DROP CASCADE should succeed
      expect do
        PgMultitenantSchemas::SchemaSwitcher.drop_schema(schema_name, cascade: true)
      end.not_to raise_error
    end
  end
end
