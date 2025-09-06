# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgMultitenantSchemas::Context do
  before do
    # Clear thread-local variables
    Thread.current[:pg_multitenant_current_tenant] = nil
    Thread.current[:pg_multitenant_current_schema] = nil
  end

  describe ".current_schema" do
    it "defaults to public schema" do
      expect(described_class.current_schema).to eq("public")
    end
  end

  describe ".current_schema=" do
    it "sets the current schema" do
      described_class.current_schema = "tenant1"
      expect(described_class.current_schema).to eq("tenant1")
    end
  end

  describe ".current_tenant" do
    it "returns nil by default" do
      expect(described_class.current_tenant).to be_nil
    end
  end

  describe ".current_tenant=" do
    it "sets the current tenant" do
      tenant = double("Tenant")
      described_class.current_tenant = tenant
      expect(described_class.current_tenant).to eq(tenant)
    end
  end
end
