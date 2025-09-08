# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgMultitenantSchemas::Migrator do
  let(:mock_connection) { double("ActiveRecord Connection") }
  let(:test_schemas) { %w[tenant_a tenant_b] }
  let(:mock_tenant) { double("Tenant", subdomain: "test_tenant") }

  before do
    # Mock the schema operations
    allow(PgMultitenantSchemas::SchemaSwitcher).to receive(:connection).and_return(mock_connection)
    allow(described_class).to receive(:switch_to_schema)
    allow(described_class).to receive_messages(tenant_schemas: test_schemas, schema_exists?: true,
                                               current_schema: "public", pending_migrations: [])
    allow(described_class).to receive(:run_migrations)
  end

  describe ".migrate_all" do
    context "with successful migrations" do
      before do
        allow(described_class).to receive(:migrate_tenant).and_return(
          { schema: "tenant_a", status: :success, message: "Migration completed" }
        )
      end

      it "migrates all tenant schemas" do
        results = described_class.migrate_all(verbose: false)

        expect(results).to all(include(status: :success))
        expect(results.count).to eq(test_schemas.count)
      end

      it "displays migration summary when verbose" do
        expect { described_class.migrate_all(verbose: true) }.to output(/Migration Summary/).to_stdout
      end

      it "calls migrate_tenant for each schema" do
        expect(described_class).to receive(:migrate_tenant).twice

        described_class.migrate_all(verbose: false)
      end
    end

    context "with migration errors" do
      before do
        allow(described_class).to receive(:migrate_tenant).and_return(
          { schema: "tenant_a", status: :error, message: "Migration failed" }
        )
      end

      it "continues with ignore_errors option" do
        results = described_class.migrate_all(verbose: false, ignore_errors: true)

        expect(results).to all(include(status: :error))
        expect(results.count).to eq(test_schemas.count)
      end
    end
  end

  describe ".migrate_tenant" do
    let(:schema_name) { "test_tenant" }

    context "when schema exists" do
      it "successfully migrates the tenant" do
        allow(described_class).to receive(:pending_migrations).and_return([])

        result = described_class.migrate_tenant(schema_name, verbose: false)

        expect(result).to include(
          schema: schema_name,
          status: :success
        )
      end

      it "switches to the correct schema" do
        expect(described_class).to receive(:switch_to_schema).with(schema_name)

        described_class.migrate_tenant(schema_name, verbose: false)
      end

      it "restores original schema after migration" do
        original_schema = "public"
        allow(described_class).to receive(:current_schema).and_return(original_schema)

        expect(described_class).to receive(:switch_to_schema).with(original_schema)

        described_class.migrate_tenant(schema_name, verbose: false)
      end
    end

    context "when schema does not exist" do
      before do
        allow(described_class).to receive(:schema_exists?).with(schema_name).and_return(false)
      end

      it "returns skipped status with raise_on_error false" do
        result = described_class.migrate_tenant(schema_name, verbose: false, raise_on_error: false)

        expect(result).to include(
          schema: schema_name,
          status: :skipped
        )
      end

      it "raises error with raise_on_error true" do
        expect do
          described_class.migrate_tenant(schema_name, verbose: false, raise_on_error: true)
        end.to raise_error(StandardError, /does not exist/)
      end
    end

    context "when migration fails" do
      before do
        allow(described_class).to receive(:schema_exists?).with(schema_name).and_return(true)
        allow(described_class).to receive(:perform_migration_for_schema).and_raise(StandardError, "Migration error")
      end

      it "returns error status with raise_on_error false" do
        result = described_class.migrate_tenant(schema_name, verbose: false, raise_on_error: false)

        expect(result).to include(
          schema: schema_name,
          status: :error
        )
      end

      it "raises error with raise_on_error true" do
        expect do
          described_class.migrate_tenant(schema_name, verbose: false, raise_on_error: true)
        end.to raise_error(StandardError, "Migration error")
      end
    end
  end

  describe ".setup_tenant" do
    let(:schema_name) { "new_tenant" }

    before do
      allow(described_class).to receive(:create_schema)
      allow(described_class).to receive(:migrate_tenant).and_return(
        { schema: schema_name, status: :success }
      )
    end

    context "when schema does not exist" do
      before do
        allow(described_class).to receive(:schema_exists?).and_return(false)
      end

      it "creates schema and runs migrations" do
        expect(described_class).to receive(:create_schema).with(schema_name)
        expect(described_class).to receive(:migrate_tenant).with(schema_name, verbose: false)

        described_class.setup_tenant(schema_name, verbose: false)
      end

      it "displays setup progress when verbose" do
        expect { described_class.setup_tenant(schema_name, verbose: true) }
          .to output(/Setting up tenant/).to_stdout
      end
    end

    context "when schema already exists" do
      before do
        allow(described_class).to receive(:schema_exists?).and_return(true)
      end

      it "skips schema creation but runs migrations" do
        expect(described_class).not_to receive(:create_schema)
        expect(described_class).to receive(:migrate_tenant)

        described_class.setup_tenant(schema_name, verbose: false)
      end
    end

    context "when setup fails" do
      before do
        allow(described_class).to receive(:migrate_tenant).and_raise(StandardError, "Setup failed")
      end

      it "raises the error" do
        expect do
          described_class.setup_tenant(schema_name, verbose: false)
        end.to raise_error(StandardError, "Setup failed")
      end

      it "displays failure message when verbose" do
        expect do
          described_class.setup_tenant(schema_name, verbose: true)
        rescue StandardError
          # Expected to raise
        end.to output(/Setup failed/).to_stdout
      end
    end
  end

  describe ".setup_all_tenants" do
    before do
      stub_const("Tenant", Class.new)
      allow(Tenant).to receive(:all).and_return([mock_tenant])
      allow(described_class).to receive(:setup_tenant).and_return(
        { schema: "test_tenant", status: :success }
      )
    end

    it "sets up all tenants from Tenant model" do
      expect(described_class).to receive(:setup_tenant).with("test_tenant", verbose: false)

      described_class.setup_all_tenants(verbose: false)
    end

    it "displays setup summary when verbose" do
      expect { described_class.setup_all_tenants(verbose: true) }
        .to output(/Setup Summary/).to_stdout
    end

    context "when Tenant model is not defined" do
      before do
        hide_const("Tenant")
      end

      it "raises an error" do
        expect do
          described_class.setup_all_tenants(verbose: false)
        end.to raise_error(/Tenant model not found/)
      end
    end
  end

  describe ".create_tenant_with_schema" do
    let(:tenant_attributes) { { subdomain: "new_client" } }

    before do
      stub_const("Tenant", Class.new)
      allow(Tenant).to receive(:create!).and_return(mock_tenant)
      allow(described_class).to receive(:setup_tenant).and_return(
        { schema: "test_tenant", status: :success }
      )
    end

    it "creates tenant and sets up schema" do
      expect(Tenant).to receive(:create!).with(tenant_attributes)
      expect(described_class).to receive(:setup_tenant).with("test_tenant", verbose: false)

      tenant = described_class.create_tenant_with_schema(tenant_attributes, verbose: false)
      expect(tenant).to eq(mock_tenant)
    end

    it "displays creation progress when verbose" do
      expect { described_class.create_tenant_with_schema(tenant_attributes, verbose: true) }
        .to output(/Creating new tenant/).to_stdout
    end
  end

  describe ".rollback_tenant" do
    it "rolls back specified number of steps" do
      schema_name = "test_tenant"
      steps = 2
      mock_migration_context = double("MigrationContext")

      allow(described_class).to receive(:switch_to_schema)
      allow(described_class).to receive_messages(current_schema: "public", migration_paths: ["/path/to/migrations"])
      allow(ActiveRecord::Base).to receive(:connection).and_return(double(migration_context: mock_migration_context))
      allow(mock_migration_context).to receive(:rollback)

      expect(mock_migration_context).to receive(:rollback)
        .with(["/path/to/migrations"], steps)

      described_class.rollback_tenant(schema_name, steps: steps, verbose: false)
    end

    it "switches to tenant schema before rollback" do
      schema_name = "test_tenant"
      steps = 2
      mock_migration_context = double("MigrationContext")

      allow(described_class).to receive(:switch_to_schema)
      allow(described_class).to receive_messages(current_schema: "public", migration_paths: ["/path/to/migrations"])
      allow(ActiveRecord::Base).to receive(:connection).and_return(double(migration_context: mock_migration_context))
      allow(mock_migration_context).to receive(:rollback)

      expect(described_class).to receive(:switch_to_schema).with(schema_name).ordered
      expect(mock_migration_context).to receive(:rollback).ordered

      described_class.rollback_tenant(schema_name, steps: steps, verbose: false)
    end

    it "restores original schema after rollback" do
      schema_name = "test_tenant"
      steps = 2
      original_schema = "public"
      mock_migration_context = double("MigrationContext")

      allow(described_class).to receive(:switch_to_schema)
      allow(described_class).to receive_messages(current_schema: original_schema,
                                                 migration_paths: ["/path/to/migrations"])
      allow(ActiveRecord::Base).to receive(:connection).and_return(double(migration_context: mock_migration_context))
      allow(mock_migration_context).to receive(:rollback)

      expect(described_class).to receive(:switch_to_schema).with(original_schema)

      described_class.rollback_tenant(schema_name, steps: steps, verbose: false)
    end

    context "when rollback fails" do
      it "raises the error" do
        schema_name = "test_tenant"
        steps = 2
        mock_migration_context = double("MigrationContext")

        allow(described_class).to receive(:switch_to_schema)
        allow(described_class).to receive_messages(current_schema: "public", migration_paths: ["/path/to/migrations"])
        allow(ActiveRecord::Base).to receive(:connection).and_return(double(migration_context: mock_migration_context))
        allow(mock_migration_context).to receive(:rollback).and_raise(StandardError, "Rollback failed")

        expect do
          described_class.rollback_tenant(schema_name, steps: steps, verbose: false)
        end.to raise_error(StandardError, "Rollback failed")
      end

      it "still restores original schema" do
        schema_name = "test_tenant"
        steps = 2
        original_schema = "public"
        mock_migration_context = double("MigrationContext")

        allow(described_class).to receive(:switch_to_schema)
        allow(described_class).to receive_messages(current_schema: original_schema,
                                                   migration_paths: ["/path/to/migrations"])
        allow(ActiveRecord::Base).to receive(:connection).and_return(double(migration_context: mock_migration_context))
        allow(mock_migration_context).to receive(:rollback).and_raise(StandardError, "Rollback failed")

        expect(described_class).to receive(:switch_to_schema).with(original_schema)

        expect do
          described_class.rollback_tenant(schema_name, steps: steps, verbose: false)
        end.to raise_error(StandardError)
      end
    end
  end
end
