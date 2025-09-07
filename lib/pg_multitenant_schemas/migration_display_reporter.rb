# frozen_string_literal: true

module PgMultitenantSchemas
  # Module for migration display and reporting functionality
  # Handles console output and summary reports for migration operations
  module MigrationDisplayReporter
    private

    def display_migration_summary(results, verbose)
      return unless verbose

      summary = results.group_by { |r| r[:status] }.transform_values(&:count)

      puts "\n📊 Migration Summary:"
      puts "  ✅ Successful: #{summary[:success] || 0}"
      puts "  ❌ Failed: #{summary[:error] || 0}"
      puts "  ⏭️  Skipped: #{summary[:skipped] || 0}"
    end

    def display_setup_summary(results, verbose)
      return unless verbose

      summary = results.group_by { |r| r[:status] }.transform_values(&:count)

      puts "\n📊 Setup Summary:"
      puts "  ✅ Successful: #{summary[:success] || 0}"
      puts "  ❌ Failed: #{summary[:error] || 0}"
    end
  end
end
