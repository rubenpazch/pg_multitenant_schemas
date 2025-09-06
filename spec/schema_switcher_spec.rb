# frozen_string_literal: true

require "pg_multitenant_schemas"
require "pg"
require "rspec"

RSpec.describe PgMultitenantSchemas::SchemaSwitcher do
  let(:conn) { double("PG::Connection") }

  it "switches to the given schema" do
    expect(conn).to receive(:exec).with('SET search_path TO "tenant1";')
    described_class.switch_schema(conn, "tenant1")
  end

  it "raises error for empty schema name" do
    expect do
      described_class.switch_schema(conn, "")
    end.to raise_error(ArgumentError)
  end

  it "resets to public schema" do
    expect(conn).to receive(:exec).with("SET search_path TO public;")
    described_class.reset_schema(conn)
  end

  it "creates a new schema" do
    expect(conn).to receive(:exec).with('CREATE SCHEMA IF NOT EXISTS "new_tenant";')
    described_class.create_schema(conn, "new_tenant")
  end

  it "drops a schema with cascade" do
    expect(conn).to receive(:exec).with('DROP SCHEMA IF EXISTS "old_tenant" CASCADE;')
    described_class.drop_schema(conn, "old_tenant")
  end
end
