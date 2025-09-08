# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgMultitenantSchemas::MigrationExecutor do
  let(:test_class) do
    Class.new do
      extend PgMultitenantSchemas::MigrationExecutor
      extend PgMultitenantSchemas::MigrationSchemaOperations

      # Mock the migrate_tenant method that would be in the main class
      def self.migrate_tenant(schema, verbose: true, raise_on_error: true)
        _ = verbose
        _ = raise_on_error
        { schema: schema, status: :success, message: "Migration completed" }
      end
    end
  end

  let(:test_schemas) { %w[tenant_a tenant_b] }

  before do
    allow(test_class).to receive(:switch_to_schema)
    allow(test_class).to receive(:run_migrations)
    allow(test_class).to receive_messages(current_schema: "public", pending_migrations: [], schema_exists?: true)
  end

  describe "#process_schemas_migration" do
    it "processes all schemas" do
      expect(test_class).to receive(:migrate_tenant).twice

      results = test_class.send(:process_schemas_migration, test_schemas, false, false)
      expect(results.count).to eq(2)
    end

    it "displays progress when verbose" do
      expect { test_class.send(:process_schemas_migration, test_schemas, true, false) }
        .to output(/Starting migrations for 2 tenant schemas/).to_stdout
    end

    it "passes correct parameters to migrate_tenant" do
      expect(test_class).to receive(:migrate_tenant)
        .with("tenant_a", verbose: false, raise_on_error: true)
      expect(test_class).to receive(:migrate_tenant)
        .with("tenant_b", verbose: false, raise_on_error: true)

      test_class.send(:process_schemas_migration, test_schemas, false, false)
    end

    it "sets raise_on_error to false when ignore_errors is true" do
      expect(test_class).to receive(:migrate_tenant)
        .with("tenant_a", verbose: false, raise_on_error: false)
      expect(test_class).to receive(:migrate_tenant)
        .with("tenant_b", verbose: false, raise_on_error: false)

      test_class.send(:process_schemas_migration, test_schemas, false, true)
    end
  end

  describe "#handle_missing_schema" do
    let(:schema_name) { "nonexistent_schema" }

    context "with raise_on_error false" do
      it "returns skipped status" do
        result = test_class.send(:handle_missing_schema, schema_name, false, false)

        expect(result).to include(
          schema: schema_name,
          status: :skipped,
          message: "Schema 'nonexistent_schema' does not exist"
        )
      end

      it "displays warning when verbose" do
        expect { test_class.send(:handle_missing_schema, schema_name, true, false) }
          .to output(/⚠️.*does not exist/).to_stdout
      end
    end

    context "with raise_on_error true" do
      it "raises StandardError" do
        expect do
          test_class.send(:handle_missing_schema, schema_name, false, true)
        end.to raise_error(StandardError, /does not exist/)
      end
    end
  end

  describe "#execute_tenant_migration" do
    let(:schema_name) { "test_tenant" }

    before do
      allow(test_class).to receive(:perform_migration_for_schema).and_return(
        { schema: schema_name, status: :success, message: "Migration completed" }
      )
    end

    it "switches to tenant schema" do
      # Allow the method calls and set up proper mocking
      allow(test_class).to receive(:switch_to_schema)
      allow(test_class).to receive_messages(current_schema: "public",
                                            perform_migration_for_schema: {
                                              schema: schema_name, status: :success, message: "Migration completed"
                                            })

      result = test_class.send(:execute_tenant_migration, schema_name, false, true)

      # Verify that the method completed successfully
      expect(result[:schema]).to eq(schema_name)
      expect(result[:status]).to eq(:success)
    end

    it "restores original schema after migration" do
      original_schema = "public"
      allow(test_class).to receive(:current_schema).and_return(original_schema)

      expect(test_class).to receive(:switch_to_schema).with(original_schema)

      test_class.send(:execute_tenant_migration, schema_name, false, true)
    end

    it "displays migration progress when verbose" do
      expect { test_class.send(:execute_tenant_migration, schema_name, true, true) }
        .to output(/📦 Migrating schema: test_tenant/).to_stdout
    end

    it "displays completion message when verbose and successful" do
      expect { test_class.send(:execute_tenant_migration, schema_name, true, true) }
        .to output(/✅ Migration completed/).to_stdout
    end

    context "when migration fails" do
      before do
        allow(test_class).to receive(:perform_migration_for_schema)
          .and_raise(StandardError, "Migration failed")
        allow(test_class).to receive(:handle_migration_error).and_return(
          { schema: schema_name, status: :error, message: "Migration failed" }
        )
      end

      it "calls handle_migration_error" do
        expect(test_class).to receive(:handle_migration_error)
          .with(schema_name, instance_of(StandardError), false, true)

        test_class.send(:execute_tenant_migration, schema_name, false, true)
      end

      it "still restores original schema" do
        original_schema = "public"
        allow(test_class).to receive(:current_schema).and_return(original_schema)

        expect(test_class).to receive(:switch_to_schema).with(original_schema)

        test_class.send(:execute_tenant_migration, schema_name, false, true)
      end
    end
  end

  describe "#perform_migration_for_schema" do
    let(:schema_name) { "test_tenant" }

    context "with no pending migrations" do
      before do
        allow(test_class).to receive(:pending_migrations).and_return([])
      end

      it "returns success with no pending migrations message" do
        result = test_class.send(:perform_migration_for_schema, schema_name, false)

        expect(result).to include(
          schema: schema_name,
          status: :success,
          message: "No pending migrations"
        )
      end

      it "displays info message when verbose" do
        expect { test_class.send(:perform_migration_for_schema, schema_name, true) }
          .to output(/ℹ️.*No pending migrations/).to_stdout
      end

      it "does not run migrations" do
        expect(test_class).not_to receive(:run_migrations)

        test_class.send(:perform_migration_for_schema, schema_name, false)
      end
    end

    context "with pending migrations" do
      let(:pending_migration) { double("Migration") }

      before do
        allow(test_class).to receive(:pending_migrations).and_return([pending_migration])
      end

      it "runs migrations and returns success" do
        expect(test_class).to receive(:run_migrations)

        result = test_class.send(:perform_migration_for_schema, schema_name, false)

        expect(result).to include(
          schema: schema_name,
          status: :success,
          message: "1 migrations applied"
        )
      end

      it "switches to correct schema before checking migrations" do
        expect(test_class).to receive(:switch_to_schema).with(schema_name).ordered
        expect(test_class).to receive(:pending_migrations).ordered

        test_class.send(:perform_migration_for_schema, schema_name, false)
      end
    end
  end

  describe "#handle_migration_error" do
    let(:schema_name) { "test_tenant" }
    let(:error) { StandardError.new("Database connection failed") }

    context "with raise_on_error false" do
      it "returns error status" do
        result = test_class.send(:handle_migration_error, schema_name, error, false, false)

        expect(result).to include(
          schema: schema_name,
          status: :error,
          message: "Migration failed: Database connection failed"
        )
      end

      it "displays error message when verbose" do
        expect { test_class.send(:handle_migration_error, schema_name, error, true, false) }
          .to output(/❌.*Migration failed/).to_stdout
      end
    end

    context "with raise_on_error true" do
      it "raises the original error" do
        expect do
          test_class.send(:handle_migration_error, schema_name, error, false, true)
        end.to raise_error(StandardError, "Database connection failed")
      end
    end
  end

  describe "#create_tenant_schema_if_needed" do
    let(:schema_name) { "new_tenant" }

    before do
      allow(test_class).to receive(:create_schema)
    end

    context "when schema does not exist" do
      before do
        allow(test_class).to receive(:schema_exists?).and_return(false)
      end

      it "creates the schema" do
        expect(test_class).to receive(:create_schema).with(schema_name)

        test_class.send(:create_tenant_schema_if_needed, schema_name, false)
      end

      it "displays creation message when verbose" do
        expect { test_class.send(:create_tenant_schema_if_needed, schema_name, true) }
          .to output(/✅ Schema created/).to_stdout
      end
    end

    context "when schema already exists" do
      before do
        allow(test_class).to receive(:schema_exists?).and_return(true)
      end

      it "does not create the schema" do
        expect(test_class).not_to receive(:create_schema)

        test_class.send(:create_tenant_schema_if_needed, schema_name, false)
      end

      it "displays info message when verbose" do
        expect { test_class.send(:create_tenant_schema_if_needed, schema_name, true) }
          .to output(/ℹ️.*Schema already exists/).to_stdout
      end
    end
  end

  describe "#validate_tenant_model_exists" do
    context "when Tenant model is defined" do
      before do
        stub_const("Tenant", Class.new)
      end

      it "does not raise an error" do
        expect { test_class.send(:validate_tenant_model_exists) }.not_to raise_error
      end
    end

    context "when Tenant model is not defined" do
      before do
        hide_const("Tenant") if defined?(Tenant)
      end

      it "raises an error" do
        expect { test_class.send(:validate_tenant_model_exists) }
          .to raise_error(/Tenant model not found/)
      end
    end
  end

  describe "#process_setup_for_tenants" do
    let(:first_tenant) { double("Tenant", subdomain: "client_a") }
    let(:second_tenant) { double("Tenant", subdomain: "client_b") }
    let(:tenants) { [first_tenant, second_tenant] }

    before do
      # Mock extract_schema_name method
      allow(test_class).to receive(:extract_schema_name).with(first_tenant).and_return("client_a")
      allow(test_class).to receive(:extract_schema_name).with(second_tenant).and_return("client_b")

      # Mock setup_tenant method
      allow(test_class).to receive(:setup_tenant).and_return(
        { schema: "client_a", status: :success }
      )
    end

    it "extracts schema names from tenants" do
      expect(test_class).to receive(:extract_schema_name).with(first_tenant)
      expect(test_class).to receive(:extract_schema_name).with(second_tenant)

      test_class.send(:process_setup_for_tenants, tenants, false)
    end

    it "calls setup_tenant for each tenant" do
      expect(test_class).to receive(:setup_tenant).with("client_a", verbose: false)
      expect(test_class).to receive(:setup_tenant).with("client_b", verbose: false)

      test_class.send(:process_setup_for_tenants, tenants, false)
    end
  end
end
