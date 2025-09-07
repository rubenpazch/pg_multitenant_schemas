# frozen_string_literal: true

require "spec_helper"
require "pg"

RSpec.describe "Multiple Schema Database Operations", :integration do
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

  let(:tenant_schemas) { %w[company_a company_b company_c] }

  before do
    # Configure the gem to use our test connection
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:connection).and_return(conn)
  end

  after do
    if defined?(conn) && conn
      tenant_schemas.each do |schema|
        conn.exec("DROP SCHEMA IF EXISTS \"#{schema}\" CASCADE;")
      end
      conn.close
    end
  end

  describe "multiple schema creation and management" do
    it "creates and manages multiple tenant schemas" do
      # Create all schemas
      tenant_schemas.each do |schema|
        PgMultitenantSchemas::SchemaSwitcher.create_schema(schema)
        expect(PgMultitenantSchemas::SchemaSwitcher.schema_exists?(schema)).to be true

        # Create identical table structure in each schema
        PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema)
        conn.exec(<<~SQL)
          CREATE TABLE customers (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            email VARCHAR(255) UNIQUE,
            tenant_schema VARCHAR(50) DEFAULT current_schema()
          );
        SQL
      end

      # Insert tenant-specific data
      tenant_schemas.each_with_index do |schema, index|
        PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema)
        conn.exec(<<~SQL)
          INSERT INTO customers (name, email) VALUES#{" "}
          ('Customer #{index + 1}', 'customer#{index + 1}@#{schema}.com'),
          ('User #{index + 1}', 'user#{index + 1}@#{schema}.com');
        SQL
      end

      # Verify data isolation
      tenant_schemas.each_with_index do |schema, _index|
        PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema)

        # Count records
        result = conn.exec("SELECT COUNT(*) FROM customers;")
        expect(result.getvalue(0, 0)).to eq("2")

        # Verify tenant_schema is correct
        result = conn.exec("SELECT DISTINCT tenant_schema FROM customers;")
        expect(result.getvalue(0, 0)).to eq(schema)

        # Verify email domains match schema
        result = conn.exec("SELECT email FROM customers ORDER BY id LIMIT 1;")
        expect(result.getvalue(0, 0)).to include("@#{schema}.com")
      end
    end

    it "handles cross-schema queries safely" do
      # Create schemas with different table structures
      PgMultitenantSchemas::SchemaSwitcher.create_schema("schema_with_users")
      PgMultitenantSchemas::SchemaSwitcher.create_schema("schema_with_products")

      # Create users table in first schema
      PgMultitenantSchemas::SchemaSwitcher.switch_schema("schema_with_users")
      conn.exec("DROP TABLE IF EXISTS users;") # Clean up first
      conn.exec("CREATE TABLE users (id SERIAL PRIMARY KEY, username VARCHAR(50));")
      conn.exec("INSERT INTO users (username) VALUES ('alice'), ('bob');")

      # Create products table in second schema
      PgMultitenantSchemas::SchemaSwitcher.switch_schema("schema_with_products")
      conn.exec("DROP TABLE IF EXISTS products;") # Clean up first
      conn.exec("CREATE TABLE products (id SERIAL PRIMARY KEY, product_name VARCHAR(50));")
      conn.exec("INSERT INTO products (product_name) VALUES ('laptop'), ('mouse');")

      # Verify isolation - users schema can't see products table
      PgMultitenantSchemas::SchemaSwitcher.switch_schema("schema_with_users")
      expect do
        conn.exec("SELECT * FROM products;")
      end.to raise_error(PG::UndefinedTable)

      # Verify isolation - products schema can't see users table
      PgMultitenantSchemas::SchemaSwitcher.switch_schema("schema_with_products")
      expect do
        conn.exec("SELECT * FROM users;")
      end.to raise_error(PG::UndefinedTable)
    end

    it "performs bulk operations across multiple schemas" do
      # Create schemas and tables
      tenant_schemas.each do |schema|
        PgMultitenantSchemas::SchemaSwitcher.create_schema(schema)
        PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema)

        conn.exec(<<~SQL)
          CREATE TABLE analytics (
            id SERIAL PRIMARY KEY,
            event_type VARCHAR(50),
            count INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT NOW()
          );
        SQL
      end

      # Insert different analytics data per schema
      tenant_schemas.each_with_index do |schema, index|
        PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema)
        event_count = (index + 1) * 50
        conn.exec("INSERT INTO analytics (event_type, count) VALUES ('page_views', #{event_count});")
      end

      # Collect analytics from all schemas
      total_views = 0
      tenant_schemas.each do |schema|
        PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema)
        result = conn.exec("SELECT count FROM analytics WHERE event_type = 'page_views';")
        total_views += result.getvalue(0, 0).to_i
      end

      expect(total_views).to eq(300) # 50 + 100 + 150
    end
  end

  describe "schema cleanup with dependencies" do
    it "cleans up multiple schemas with foreign key relationships" do
      # Create two related schemas
      PgMultitenantSchemas::SchemaSwitcher.create_schema("main_tenant")
      PgMultitenantSchemas::SchemaSwitcher.create_schema("sub_tenant")

      # Create tables with relationships in main schema
      PgMultitenantSchemas::SchemaSwitcher.switch_schema("main_tenant")
      conn.exec(<<~SQL)
        CREATE TABLE departments (
          id SERIAL PRIMARY KEY,
          name VARCHAR(100)
        );
        CREATE TABLE employees (
          id SERIAL PRIMARY KEY,
          name VARCHAR(100),
          department_id INTEGER REFERENCES departments(id)
        );
      SQL

      # Insert test data
      conn.exec("INSERT INTO departments (name) VALUES ('Engineering'), ('Sales');")
      conn.exec("INSERT INTO employees (name, department_id) VALUES ('Alice', 1), ('Bob', 2);")

      # Verify CASCADE properly handles dependencies
      expect do
        PgMultitenantSchemas::SchemaSwitcher.drop_schema("main_tenant", cascade: true)
      end.not_to raise_error

      expect(PgMultitenantSchemas::SchemaSwitcher.schema_exists?("main_tenant")).to be false
    end
  end
end
