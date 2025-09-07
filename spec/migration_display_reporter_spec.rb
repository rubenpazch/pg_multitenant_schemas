# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgMultitenantSchemas::MigrationDisplayReporter do
  let(:test_class) do
    Class.new do
      extend PgMultitenantSchemas::MigrationDisplayReporter
    end
  end

  describe "#display_migration_summary" do
    let(:results) do
      [
        { schema: "tenant_a", status: :success },
        { schema: "tenant_b", status: :success },
        { schema: "tenant_c", status: :error },
        { schema: "tenant_d", status: :skipped }
      ]
    end

    context "when verbose is true" do
      it "displays migration summary with counts" do
        output = capture_stdout do
          test_class.send(:display_migration_summary, results, true)
        end

        expect(output).to include("📊 Migration Summary:")
        expect(output).to include("✅ Successful: 2")
        expect(output).to include("❌ Failed: 1")
        expect(output).to include("⏭️  Skipped: 1")
      end

      it "handles results with only successful migrations" do
        successful_results = [
          { schema: "tenant_a", status: :success },
          { schema: "tenant_b", status: :success }
        ]

        output = capture_stdout do
          test_class.send(:display_migration_summary, successful_results, true)
        end

        expect(output).to include("✅ Successful: 2")
        expect(output).to include("❌ Failed: 0")
        expect(output).to include("⏭️  Skipped: 0")
      end

      it "handles empty results" do
        output = capture_stdout do
          test_class.send(:display_migration_summary, [], true)
        end

        expect(output).to include("📊 Migration Summary:")
        expect(output).to include("✅ Successful: 0")
        expect(output).to include("❌ Failed: 0")
        expect(output).to include("⏭️  Skipped: 0")
      end

      it "handles results with unknown status" do
        mixed_results = [
          { schema: "tenant_a", status: :success },
          { schema: "tenant_b", status: :unknown }
        ]

        output = capture_stdout do
          test_class.send(:display_migration_summary, mixed_results, true)
        end

        expect(output).to include("✅ Successful: 1")
        expect(output).to include("❌ Failed: 0")
        expect(output).to include("⏭️  Skipped: 0")
      end
    end

    context "when verbose is false" do
      it "does not display anything" do
        expect { test_class.send(:display_migration_summary, results, false) }
          .not_to output.to_stdout
      end
    end
  end

  describe "#display_setup_summary" do
    let(:results) do
      [
        { schema: "tenant_a", status: :success },
        { schema: "tenant_b", status: :error },
        { schema: "tenant_c", status: :success }
      ]
    end

    context "when verbose is true" do
      it "displays setup summary with counts" do
        output = capture_stdout do
          test_class.send(:display_setup_summary, results, true)
        end

        expect(output).to include("📊 Setup Summary:")
        expect(output).to include("✅ Successful: 2")
        expect(output).to include("❌ Failed: 1")
      end

      it "handles all successful setups" do
        successful_results = [
          { schema: "tenant_a", status: :success },
          { schema: "tenant_b", status: :success }
        ]

        output = capture_stdout do
          test_class.send(:display_setup_summary, successful_results, true)
        end

        expect(output).to include("✅ Successful: 2")
        expect(output).to include("❌ Failed: 0")
      end

      it "handles all failed setups" do
        failed_results = [
          { schema: "tenant_a", status: :error },
          { schema: "tenant_b", status: :error }
        ]

        output = capture_stdout do
          test_class.send(:display_setup_summary, failed_results, true)
        end

        expect(output).to include("✅ Successful: 0")
        expect(output).to include("❌ Failed: 2")
      end

      it "handles empty results" do
        output = capture_stdout do
          test_class.send(:display_setup_summary, [], true)
        end

        expect(output).to include("📊 Setup Summary:")
        expect(output).to include("✅ Successful: 0")
        expect(output).to include("❌ Failed: 0")
      end

      it "groups by status correctly" do
        complex_results = [
          { schema: "tenant_a", status: :success },
          { schema: "tenant_b", status: :error },
          { schema: "tenant_c", status: :success },
          { schema: "tenant_d", status: :error },
          { schema: "tenant_e", status: :success }
        ]

        output = capture_stdout do
          test_class.send(:display_setup_summary, complex_results, true)
        end

        expect(output).to include("✅ Successful: 3")
        expect(output).to include("❌ Failed: 2")
      end
    end

    context "when verbose is false" do
      it "does not display anything" do
        expect { test_class.send(:display_setup_summary, results, false) }
          .not_to output.to_stdout
      end
    end
  end

  describe "summary formatting" do
    it "uses consistent emoji and formatting" do
      results = [{ schema: "tenant_a", status: :success }]

      output = capture_stdout do
        test_class.send(:display_migration_summary, results, true)
      end

      # Check for consistent formatting
      expect(output).to match(/📊 Migration Summary:/)
      expect(output).to match(/✅ Successful: \d+/)
      expect(output).to match(/❌ Failed: \d+/)
      expect(output).to match(/⏭️  Skipped: \d+/)
    end

    it "includes newlines for proper formatting" do
      results = [{ schema: "tenant_a", status: :success }]

      output = capture_stdout do
        test_class.send(:display_migration_summary, results, true)
      end

      # Should start with newline
      expect(output).to start_with("\n")
    end
  end

  describe "status counting edge cases" do
    it "handles nil status gracefully" do
      results = [
        { schema: "tenant_a", status: nil },
        { schema: "tenant_b", status: :success }
      ]

      output = capture_stdout do
        test_class.send(:display_migration_summary, results, true)
      end

      expect(output).to include("✅ Successful: 1")
      expect(output).to include("❌ Failed: 0")
      expect(output).to include("⏭️  Skipped: 0")
    end

    it "handles mixed status types" do
      results = [
        { schema: "tenant_a", status: "success" },  # String instead of symbol
        { schema: "tenant_b", status: :error }
      ]

      output = capture_stdout do
        test_class.send(:display_migration_summary, results, true)
      end

      # Should handle gracefully without crashing
      expect(output).to include("📊 Migration Summary:")
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
