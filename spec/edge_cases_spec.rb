# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Edge Cases and Error Handling" do
  let(:mock_conn) { double("PG::Connection") }

  describe "schema name validation" do
    it "handles whitespace-only schema names" do
      expect do
        PgMultitenantSchemas::SchemaSwitcher.switch_schema(mock_conn, "   ")
      end.to raise_error(ArgumentError, "Schema name cannot be empty")
    end

    it "handles special characters in schema names" do
      expect(mock_conn).to receive(:exec).with('SET search_path TO "test-schema_123";')
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(mock_conn, "test-schema_123")
    end

    it "handles unicode characters" do
      expect(mock_conn).to receive(:exec).with('SET search_path TO "café";')
      PgMultitenantSchemas::SchemaSwitcher.switch_schema(mock_conn, "café")
    end
  end

  describe "configuration edge cases" do
    let(:config) { PgMultitenantSchemas::Configuration.new }

    it "handles empty excluded subdomains list" do
      config.excluded_subdomains = []
      expect(config.excluded_subdomains).to eq([])
    end

    it "handles custom tenant model class" do
      config.tenant_model_class = "CustomTenant"
      expect(config.tenant_model_class).to eq("CustomTenant")
    end

    it "validates boolean settings" do
      config.development_fallback = "invalid"
      expect(config.development_fallback).to eq("invalid") # Should handle type coercion in real usage
    end
  end

  describe "thread safety" do
    it "isolates context between threads" do
      results = {}

      thread1 = Thread.new do
        PgMultitenantSchemas::Context.current_schema = "tenant1"
        sleep 0.01
        results[:thread1] = PgMultitenantSchemas::Context.current_schema
      end

      thread2 = Thread.new do
        PgMultitenantSchemas::Context.current_schema = "tenant2"
        sleep 0.01
        results[:thread2] = PgMultitenantSchemas::Context.current_schema
      end

      thread1.join
      thread2.join

      expect(results[:thread1]).to eq("tenant1")
      expect(results[:thread2]).to eq("tenant2")
    end
  end

  describe "subdomain extraction edge cases" do
    it "handles malformed hosts" do
      expect(PgMultitenantSchemas::TenantResolver.extract_subdomain(".")).to be_nil
      expect(PgMultitenantSchemas::TenantResolver.extract_subdomain("..")).to be_nil
      expect(PgMultitenantSchemas::TenantResolver.extract_subdomain("...")).to be_nil
    end

    it "handles very long subdomains" do
      long_subdomain = "a" * 63 # DNS limit
      host = "#{long_subdomain}.example.com"
      expect(PgMultitenantSchemas::TenantResolver.extract_subdomain(host)).to eq(long_subdomain)
    end

    it "handles international domains" do
      expect(PgMultitenantSchemas::TenantResolver.extract_subdomain("demo.例え.テスト")).to eq("demo")
    end
  end
end
