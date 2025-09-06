# frozen_string_literal: true

require "spec_helper"
require "pg"

RSpec.describe "PostgreSQL Integration Tests", :integration do
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

  after do
    # Clean up test schemas
    if defined?(conn) && conn
      conn.exec("DROP SCHEMA IF EXISTS test_schema CASCADE;")
      conn.exec("DROP SCHEMA IF EXISTS another_test_schema CASCADE;")
      conn.close
    end
  end

  describe "schema creation" do
    it "actually creates a schema in PostgreSQL" do
      schema_name = "test_schema"

      # Create the schema
      PgMultitenantSchemas::SchemaSwitcher.create_schema(conn, schema_name)

      # Verify it exists
      result = conn.exec(<<~SQL)
        SELECT EXISTS(
          SELECT 1 FROM information_schema.schemata#{" "}
          WHERE schema_name = '#{schema_name}'
        ) AS schema_exists
      SQL

      expect(result.getvalue(0, 0)).to eq("t")
    end

    it "does not fail when creating existing schema" do
      schema_name = "test_schema"

      # Create schema twice
      expect do
        PgMultitenantSchemas::SchemaSwitcher.create_schema(conn, schema_name)
        PgMultitenantSchemas::SchemaSwitcher.create_schema(conn, schema_name)
      end.not_to raise_error
    end
  end

  describe "schema switching" do
    it "actually switches the search_path" do
      schema_name = "test_schema"

      # Create and switch to schema
      PgMultitenantSchemas::SchemaSwitcher.create_schema(conn, schema_name)
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(conn, schema_name)

      # Verify current schema
      current_schema = PgMultitenantSchemas::SchemaSwitcher.current_schema(conn)
      expect(current_schema).to eq(schema_name)
    end
  end

  describe "schema deletion" do
    it "actually drops a schema from PostgreSQL" do
      schema_name = "test_schema"

      # Create then drop schema
      PgMultitenantSchemas::SchemaSwitcher.create_schema(conn, schema_name)
      PgMultitenantSchemas::SchemaSwitcher.drop_schema(conn, schema_name)

      # Verify it's gone
      exists = PgMultitenantSchemas::SchemaSwitcher.schema_exists?(conn, schema_name)
      expect(exists).to be false
    end
  end

  describe "schema_exists?" do
    it "correctly identifies existing schemas" do
      schema_name = "test_schema"

      # Should not exist initially
      expect(PgMultitenantSchemas::SchemaSwitcher.schema_exists?(conn, schema_name)).to be false

      # Create schema
      PgMultitenantSchemas::SchemaSwitcher.create_schema(conn, schema_name)

      # Should exist now
      expect(PgMultitenantSchemas::SchemaSwitcher.schema_exists?(conn, schema_name)).to be true
    end
  end

  describe "table operations in tenant schema" do
    it "creates tables in the correct schema" do
      schema_name = "test_schema"

      # Create schema and switch to it
      PgMultitenantSchemas::SchemaSwitcher.create_schema(conn, schema_name)
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(conn, schema_name)

      # Create a table
      conn.exec("CREATE TABLE test_table (id SERIAL PRIMARY KEY, name VARCHAR(50));")

      # Verify table exists in the correct schema
      result = conn.exec(<<~SQL)
        SELECT EXISTS(
          SELECT 1 FROM information_schema.tables#{" "}
          WHERE table_schema = '#{schema_name}'#{" "}
          AND table_name = 'test_table'
        ) AS table_exists
      SQL

      expect(result.getvalue(0, 0)).to eq("t")

      # Clean up
      conn.exec("DROP TABLE test_table;")
    end
  end
end
