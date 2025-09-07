# frozen_string_literal: true

module PgMultitenantSchemas
  # Migration status reporting functionality
  module MigrationStatusReporter
    # Check migration status across all tenants
    def migration_status(verbose: true)
      schemas = tenant_schemas
      results = collect_migration_status_for_schemas(schemas)
      display_status_report(results, verbose)
      results
    end

    private

    def collect_migration_status_for_schemas(schemas)
      schemas.map do |schema|
        collect_status_for_schema(schema)
      end
    end

    def collect_status_for_schema(schema)
      original_schema = current_schema

      begin
        switch_to_schema(schema)
        build_schema_status(schema)
      rescue StandardError => e
        { schema: schema, error: e.message, status: :error }
      ensure
        switch_to_schema(original_schema) if original_schema
      end
    end

    def build_schema_status(schema)
      pending = pending_migrations
      applied = applied_migrations

      {
        schema: schema,
        pending_count: pending.count,
        applied_count: applied.count,
        status: pending.any? ? :pending : :up_to_date
      }
    end

    def display_status_report(results, verbose)
      return unless verbose

      puts "📋 Migration Status Report:"
      results.each { |result| display_schema_status(result) }
    end

    def display_schema_status(result)
      case result[:status]
      when :up_to_date
        puts "  ✅ #{result[:schema]}: Up to date (#{result[:applied_count]} applied)"
      when :pending
        puts "  ⏳ #{result[:schema]}: #{result[:pending_count]} pending, #{result[:applied_count]} applied"
      when :error
        puts "  ❌ #{result[:schema]}: Error - #{result[:error]}"
      end
    end
  end
end
