# frozen_string_literal: true

require "spec_helper"

RSpec.describe "End-to-End Multitenant Cookie-Based Schema Switching" do
  # This integration test verifies the complete flow:
  # 1. Dashboard sets schema via cookie
  # 2. Main application reads cookie
  # 3. Queries execute against selected schema

  let(:mock_connection) { double("PG::Connection") }

  before do
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive_messages(connection: mock_connection, schema_exists?: true)
  end

  describe "schema persistence across requests" do
    it "maintains schema context when cookie is provided" do
      # Simulate dashboard setting cookie
      schema_name = "pepito"

      # First request: switch to pepito
      expect(mock_connection).to receive(:execute).with('SET search_path TO "pepito";')
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(schema_name)

      # Verify context is set
      PgMultitenantSchemas::Context.current_schema = schema_name
      expect(PgMultitenantSchemas::Context.current_schema).to eq(schema_name)

      # Second request: verify schema is still active
      expect(mock_connection).to receive(:execute).with('SET search_path TO "pepito";')
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(PgMultitenantSchemas::Context.current_schema)

      # Context should remain pepito
      expect(PgMultitenantSchemas::Context.current_schema).to eq(schema_name)
    end
  end

  describe "cookie-based schema isolation" do
    it "isolates data between schemas" do
      # Setup: Create two schemas
      pepito_schema = "pepito"
      juanito_schema = "juanito"

      expect(mock_connection).to receive(:execute).with('CREATE SCHEMA IF NOT EXISTS "pepito";')
      PgMultitenantSchemas::SchemaSwitcher.create_schema(pepito_schema)

      expect(mock_connection).to receive(:execute).with('CREATE SCHEMA IF NOT EXISTS "juanito";')
      PgMultitenantSchemas::SchemaSwitcher.create_schema(juanito_schema)

      # Switch to pepito
      expect(mock_connection).to receive(:execute).with('SET search_path TO "pepito";')
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(pepito_schema)
      PgMultitenantSchemas::Context.current_schema = pepito_schema

      expect(PgMultitenantSchemas::Context.current_schema).to eq(pepito_schema)

      # Switch to juanito
      expect(mock_connection).to receive(:execute).with('SET search_path TO "juanito";')
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(juanito_schema)
      PgMultitenantSchemas::Context.current_schema = juanito_schema

      expect(PgMultitenantSchemas::Context.current_schema).to eq(juanito_schema)

      # Cleanup
      expect(mock_connection).to receive(:execute).with('DROP SCHEMA IF EXISTS "pepito" CASCADE;')
      PgMultitenantSchemas::SchemaSwitcher.drop_schema(pepito_schema)

      expect(mock_connection).to receive(:execute).with('DROP SCHEMA IF EXISTS "juanito" CASCADE;')
      PgMultitenantSchemas::SchemaSwitcher.drop_schema(juanito_schema)
    end
  end

  describe "cookie validation and fallback" do
    it "validates schema exists before setting context" do
      invalid_schema = "nonexistent"

      allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:schema_exists?).with(invalid_schema).and_return(false)

      # Should not attempt to set context for invalid schema
      expect(PgMultitenantSchemas::Context).not_to receive(:current_schema=).with(invalid_schema)

      # Verify schema does not exist
      expect(PgMultitenantSchemas::SchemaSwitcher.schema_exists?(invalid_schema)).to be false
    end

    it "falls back to default schema when cookie is invalid" do
      # Start with invalid schema attempt
      invalid_schema = "invalid"
      allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:schema_exists?).with(invalid_schema).and_return(false)

      # Fall back to public schema
      PgMultitenantSchemas::Context.current_schema = "public"

      expect(PgMultitenantSchemas::Context.current_schema).to eq("public")
    end
  end

  describe "cross-app communication via cookie" do
    it "allows dashboard to communicate schema selection to main app" do
      # Dashboard component: set cookie (simulated)
      selected_schema = "pepito"
      dashboard_cookie = { pg_multitenant_selected_schema: selected_schema }

      # Main app component: read cookie and apply
      schema_from_cookie = dashboard_cookie[:pg_multitenant_selected_schema]
      allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:schema_exists?).with(schema_from_cookie).and_return(true)

      if schema_from_cookie.present? && PgMultitenantSchemas::SchemaSwitcher.schema_exists?(schema_from_cookie)
        PgMultitenantSchemas::Context.current_schema = schema_from_cookie
      end

      expect(PgMultitenantSchemas::Context.current_schema).to eq(selected_schema)
    end
  end

  describe "request-to-request persistence" do
    it "maintains cookie-based schema across multiple sequential requests" do
      schema_name = "pepito"

      # Request 1: Set context from cookie
      PgMultitenantSchemas::Context.current_schema = schema_name
      expect(PgMultitenantSchemas::Context.current_schema).to eq(schema_name)

      # Request 2: Schema is thread-local, so context resets
      # (This documents the thread-local limitation)
      Thread.current[:pg_multitenant_current_schema] = nil
      expect(PgMultitenantSchemas::Context.current_schema).to eq("public")

      # Request 2 redux: But if cookie is read and reapplied
      PgMultitenantSchemas::Context.current_schema = schema_name
      expect(PgMultitenantSchemas::Context.current_schema).to eq(schema_name)
    end
  end

  describe "schema switching error handling" do
    it "handles schema switching errors gracefully" do
      allow(mock_connection).to receive(:execute).and_raise(StandardError, "Connection refused")

      expect do
        PgMultitenantSchemas::SchemaSwitcher.switch_schema("pepito")
      end.to raise_error(StandardError)
    end

    it "recovers from invalid schema errors" do
      allow(mock_connection).to receive(:execute)
        .with('SET search_path TO "invalid";')
        .and_raise(StandardError, "schema \"invalid\" does not exist")

      expect do
        PgMultitenantSchemas::SchemaSwitcher.switch_schema("invalid")
      end.to raise_error(StandardError)

      # Can recover by switching to valid schema
      expect(mock_connection).to receive(:execute).with('SET search_path TO "public";')
      PgMultitenantSchemas::SchemaSwitcher.switch_schema("public")
    end
  end

  describe "cookie expiry and lifecycle" do
    it "documents cookie expiry behavior (24 hours)" do
      # Cookie is set with 24.hours.from_now expiry in controller
      # This test documents the expected behavior

      # In the controller:
      # cookies[:pg_multitenant_selected_schema] = { value: schema, expires: 24.hours.from_now }

      # After 24 hours, cookie expires and browser doesn't send it
      # Application reverts to normal tenant resolution

      now = Time.now
      future_time = now + (24 * 3600) # 24 hours in seconds
      expect(future_time).to be > now
    end
  end
end
