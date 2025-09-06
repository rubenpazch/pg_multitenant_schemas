# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Integration Tests" do
  let(:mock_conn) { double("PG::Connection") }

  describe "schema operations workflow" do
    it "performs a complete schema lifecycle" do
      schema_name = "test_tenant"

      # Create schema
      expect(mock_conn).to receive(:exec).with('CREATE SCHEMA IF NOT EXISTS "test_tenant";')
      PgMultitenantSchemas::SchemaSwitcher.create_schema(mock_conn, schema_name)

      # Switch to schema
      expect(mock_conn).to receive(:exec).with('SET search_path TO "test_tenant";')
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(mock_conn, schema_name)

      # Drop schema
      expect(mock_conn).to receive(:exec).with('DROP SCHEMA IF EXISTS "test_tenant" CASCADE;')
      PgMultitenantSchemas::SchemaSwitcher.drop_schema(mock_conn, schema_name)
    end
  end

  describe "context management" do
    it "manages tenant and schema context" do
      tenant = double("Tenant", subdomain: "demo")

      # Set tenant
      PgMultitenantSchemas::Context.current_tenant = tenant
      expect(PgMultitenantSchemas::Context.current_tenant).to eq(tenant)

      # Set schema
      PgMultitenantSchemas::Context.current_schema = "demo"
      expect(PgMultitenantSchemas::Context.current_schema).to eq("demo")

      # Reset context
      Thread.current[:pg_multitenant_current_tenant] = nil
      Thread.current[:pg_multitenant_current_schema] = nil
      expect(PgMultitenantSchemas::Context.current_tenant).to be_nil
      expect(PgMultitenantSchemas::Context.current_schema).to eq("public")
    end
  end

  describe "error handling" do
    it "raises appropriate errors for invalid operations" do
      expect do
        PgMultitenantSchemas::SchemaSwitcher.switch_schema(mock_conn, "")
      end.to raise_error(ArgumentError, "Schema name cannot be empty")

      expect do
        PgMultitenantSchemas::SchemaSwitcher.create_schema(mock_conn, nil)
      end.to raise_error(ArgumentError, "Schema name cannot be empty")
    end
  end

  describe "SQL injection protection" do
    it "escapes dangerous characters in schema names" do
      dangerous_name = 'test"; DROP TABLE users; --'
      escaped_sql = 'SET search_path TO "test""; DROP TABLE users; --";'

      expect(mock_conn).to receive(:exec).with(escaped_sql)
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(mock_conn, dangerous_name)
    end
  end
end
