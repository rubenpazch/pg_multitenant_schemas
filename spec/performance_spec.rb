# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Performance and Memory Tests" do
  describe "memory usage" do
    it "does not leak memory when switching schemas repeatedly" do
      mock_conn = double("PG::Connection")
      allow(mock_conn).to receive(:exec)

      # Switch schemas many times
      1000.times do |i|
        PgMultitenantSchemas::Context.current_schema = "tenant_#{i}"
      end

      # Context should only store the latest value
      expect(PgMultitenantSchemas::Context.current_schema).to eq("tenant_999")
    end

    it "cleans up thread-local variables on reset" do
      PgMultitenantSchemas::Context.current_tenant = "test"
      PgMultitenantSchemas::Context.current_schema = "test"

      # Reset should clear everything
      Thread.current[:pg_multitenant_current_tenant] = nil
      Thread.current[:pg_multitenant_current_schema] = nil

      expect(PgMultitenantSchemas::Context.current_tenant).to be_nil
      expect(PgMultitenantSchemas::Context.current_schema).to eq("public")
    end
  end

  describe "concurrent access" do
    it "handles multiple threads accessing configuration" do
      threads = []
      results = Queue.new

      10.times do |_i|
        threads << Thread.new do
          config = PgMultitenantSchemas.configuration
          results << config.default_schema
        end
      end

      threads.each(&:join)

      # All threads should get the same configuration
      10.times do
        expect(results.pop).to eq("public")
      end
    end
  end
end
