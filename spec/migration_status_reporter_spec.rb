# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgMultitenantSchemas::MigrationStatusReporter do
  let(:test_class) do
    Class.new do
      extend PgMultitenantSchemas::MigrationStatusReporter
      extend PgMultitenantSchemas::MigrationSchemaOperations
    end
  end

  let(:test_schemas) { ["tenant_a", "tenant_b"] }
  let(:mock_connection) { double("ActiveRecord Connection") }

  before do
    allow(test_class).to receive(:tenant_schemas).and_return(test_schemas)
    allow(test_class).to receive(:current_schema).and_return("public")
    allow(test_class).to receive(:switch_to_schema)
    allow(test_class).to receive(:pending_migrations).and_return([])
    allow(test_class).to receive(:applied_migrations).and_return(["001", "002"])
  end

  describe "#migration_status" do
    it "collects status for all schemas" do
      expect(test_class).to receive(:collect_status_for_schema).twice.and_return(
        { schema: "tenant_a", pending_count: 0, applied_count: 2, status: :up_to_date }
      )

      results = test_class.migration_status(verbose: false)
      expect(results.count).to eq(2)
    end

    it "displays status report when verbose" do
      allow(test_class).to receive(:collect_status_for_schema).and_return(
        { schema: "tenant_a", pending_count: 0, applied_count: 2, status: :up_to_date }
      )

      expect { test_class.migration_status(verbose: true) }
        .to output(/Migration Status Report/).to_stdout
    end
  end

  describe "#collect_status_for_schema" do
    let(:schema_name) { "test_tenant" }

    context "when schema is up to date" do
      before do
        allow(test_class).to receive(:pending_migrations).and_return([])
        allow(test_class).to receive(:applied_migrations).and_return(["001", "002"])
      end

      it "returns up_to_date status" do
        result = test_class.send(:collect_status_for_schema, schema_name)

        expect(result).to include(
          schema: schema_name,
          pending_count: 0,
          applied_count: 2,
          status: :up_to_date
        )
      end

      it "switches to the schema" do
        expect(test_class).to receive(:switch_to_schema).with(schema_name)

        test_class.send(:collect_status_for_schema, schema_name)
      end

      it "restores original schema" do
        original_schema = "public"
        allow(test_class).to receive(:current_schema).and_return(original_schema)

        expect(test_class).to receive(:switch_to_schema).with(original_schema)

        test_class.send(:collect_status_for_schema, schema_name)
      end
    end

    context "when schema has pending migrations" do
      let(:pending_migration) { double("Migration", name: "AddUsersTable") }

      before do
        allow(test_class).to receive(:pending_migrations).and_return([pending_migration])
        allow(test_class).to receive(:applied_migrations).and_return(["001"])
      end

      it "returns pending status" do
        result = test_class.send(:collect_status_for_schema, schema_name)

        expect(result).to include(
          schema: schema_name,
          pending_count: 1,
          applied_count: 1,
          status: :pending
        )
      end
    end

    context "when schema analysis fails" do
      before do
        allow(test_class).to receive(:current_schema).and_return("public")
        allow(test_class).to receive(:switch_to_schema).with(schema_name).and_raise(StandardError, "Connection error")
        allow(test_class).to receive(:switch_to_schema).with("public") # Allow restoration to succeed
      end

      it "returns error status" do
        result = test_class.send(:collect_status_for_schema, schema_name)

        expect(result).to include(
          schema: schema_name,
          error: "Connection error",
          status: :error
        )
      end
    end
  end

  describe "#display_status_report" do
    let(:results) do
      [
        { schema: "tenant_a", applied_count: 2, status: :up_to_date },
        { schema: "tenant_b", pending_count: 1, applied_count: 1, status: :pending },
        { schema: "tenant_c", error: "Connection failed", status: :error }
      ]
    end

    it "displays status for all schemas when verbose" do
      output = capture_stdout do
        test_class.send(:display_status_report, results, true)
      end

      expect(output).to include("Migration Status Report")
      expect(output).to include("tenant_a")
      expect(output).to include("Up to date")
      expect(output).to include("pending")
      expect(output).to include("Error")
    end

    it "does not display when not verbose" do
      expect { test_class.send(:display_status_report, results, false) }
        .not_to output.to_stdout
    end
  end

  describe "#display_schema_status" do
    context "with up_to_date status" do
      let(:result) { { schema: "tenant_a", applied_count: 2, status: :up_to_date } }

      it "displays success message" do
        expect { test_class.send(:display_schema_status, result) }
          .to output(/✅ tenant_a: Up to date/).to_stdout
      end
    end

    context "with pending status" do
      let(:result) { { schema: "tenant_b", pending_count: 1, applied_count: 1, status: :pending } }

      it "displays pending message" do
        expect { test_class.send(:display_schema_status, result) }
          .to output(/⏳ tenant_b: 1 pending, 1 applied/).to_stdout
      end
    end

    context "with error status" do
      let(:result) { { schema: "tenant_c", error: "Connection failed", status: :error } }

      it "displays error message" do
        expect { test_class.send(:display_schema_status, result) }
          .to output(/❌ tenant_c: Error - Connection failed/).to_stdout
      end
    end
  end

  # Helper method to capture stdout
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
