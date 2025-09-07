# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgMultitenantSchemas::MigrationSchemaOperations do
  let(:test_class) do
    Class.new do
      extend PgMultitenantSchemas::MigrationSchemaOperations
    end
  end

  let(:mock_connection) { double("ActiveRecord Connection") }
  let(:mock_schema_switcher) { PgMultitenantSchemas::SchemaSwitcher }

  before do
    allow(mock_schema_switcher).to receive(:switch_schema)
    allow(mock_schema_switcher).to receive(:create_schema)
    allow(mock_schema_switcher).to receive(:schema_exists?)
    allow(mock_schema_switcher).to receive(:current_schema)
    allow(mock_schema_switcher).to receive(:list_schemas)
  end

  describe "#switch_to_schema" do
    let(:schema_name) { "test_schema" }

    it "delegates to SchemaSwitcher" do
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:switch_schema).with(schema_name)
      test_class.send(:switch_to_schema, schema_name)
    end
  end

  describe "#create_schema" do
    let(:schema_name) { "test_schema" }

    it "delegates to SchemaSwitcher" do
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:create_schema).with(schema_name)
      test_class.send(:create_schema, schema_name)
    end
  end

  describe "#schema_exists?" do
    let(:schema_name) { "test_schema" }

    it "delegates to SchemaSwitcher" do
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:schema_exists?).with(schema_name).and_return(true)
      result = test_class.send(:schema_exists?, schema_name)
      expect(result).to be true
    end
  end

  describe "#current_schema" do
    it "delegates to SchemaSwitcher" do
      expect(PgMultitenantSchemas::SchemaSwitcher).to receive(:current_schema).and_return("public")
      result = test_class.send(:current_schema)
      expect(result).to eq("public")
    end
  end

  describe "#tenant_schemas" do
    let(:all_schemas) do
      [
        "information_schema",
        "pg_catalog", 
        "public",
        "pg_temp_1",
        "pg_toast_temp_1",
        "pg_toast_12345",
        "tenant_a",
        "tenant_b"
      ]
    end

    before do
      allow(mock_schema_switcher).to receive(:list_schemas).and_return(all_schemas)
    end

    it "returns only tenant schemas, excluding system schemas" do
      result = test_class.send(:tenant_schemas)

      expect(result).to contain_exactly("tenant_a", "tenant_b")
      expect(result).not_to include("information_schema", "pg_catalog", "public")
      expect(result).not_to include("pg_temp_1", "pg_toast_temp_1")
      expect(result).not_to include("pg_toast_12345")
    end

    it "filters out schemas starting with pg_toast" do
      schemas_with_toast = all_schemas + ["pg_toast_99999"]
      allow(mock_schema_switcher).to receive(:list_schemas).and_return(schemas_with_toast)

      result = test_class.send(:tenant_schemas)

      expect(result).not_to include("pg_toast_99999")
    end
  end

  describe "#extract_schema_name" do
    context "with tenant responding to subdomain" do
      let(:tenant) { double("Tenant", subdomain: "client_a") }

      it "returns the subdomain" do
        result = test_class.send(:extract_schema_name, tenant)
        expect(result).to eq("client_a")
      end
    end

    context "with tenant not responding to subdomain" do
      let(:tenant) { "string_tenant" }

      it "returns string representation" do
        result = test_class.send(:extract_schema_name, tenant)
        expect(result).to eq("string_tenant")
      end
    end
  end

  describe "#run_migrations" do
    before do
      allow(ActiveRecord::Base).to receive_message_chain(:connection, :migrate)
    end

    it "delegates to ActiveRecord Base connection migrate" do
      test_class.send(:run_migrations)
      expect(ActiveRecord::Base.connection).to have_received(:migrate)
    end
  end

  describe "#pending_migrations" do
    let(:mock_migration_context) { double("MigrationContext") }
    let(:mock_connection) { double("Connection") }
    let(:migration1) { double("Migration", version: 1) }
    let(:migration2) { double("Migration", version: 2) }
    let(:migration3) { double("Migration", version: 3) }
    let(:all_migrations) { [migration1, migration2, migration3] }
    let(:applied_versions) { [1, 2] }

    before do
      allow(ActiveRecord::Base).to receive(:connection).and_return(mock_connection)
      allow(mock_connection).to receive(:migration_context).and_return(mock_migration_context)
      allow(mock_migration_context).to receive(:migrations).and_return(all_migrations)
      allow(mock_migration_context).to receive(:get_all_versions).and_return(applied_versions)
    end

    it "returns migrations not yet applied" do
      result = test_class.send(:pending_migrations)

      expect(result).to contain_exactly(migration3)
    end

    it "returns empty array when all migrations are applied" do
      allow(mock_migration_context).to receive(:get_all_versions).and_return([1, 2, 3])

      result = test_class.send(:pending_migrations)

      expect(result).to be_empty
    end
  end

  describe "#applied_migrations" do
    let(:mock_migration_context) { double("MigrationContext") }
    let(:mock_connection) { double("Connection") }
    let(:applied_versions) { [1, 2, 3] }

    before do
      allow(ActiveRecord::Base).to receive(:connection).and_return(mock_connection)
      allow(mock_connection).to receive(:migration_context).and_return(mock_migration_context)
      allow(mock_migration_context).to receive(:get_all_versions).and_return(applied_versions)
    end

    it "returns all applied migration versions" do
      result = test_class.send(:applied_migrations)

      expect(result).to eq(applied_versions)
    end
  end

  describe "#migration_paths" do
    let(:migration_paths) { ["/app/db/migrate"] }

    before do
      # Mock the migration context migrations_paths
      allow(ActiveRecord::Base).to receive_message_chain(:connection, :migration_context, :migrations_paths).and_return(migration_paths)
    end

    it "returns migration paths from ActiveRecord migration context" do
      result = test_class.send(:migration_paths)
      expect(result).to eq(migration_paths)
    end
  end
end
