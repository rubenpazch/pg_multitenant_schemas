# frozen_string_literal: true

require "spec_helper"
require "pg"

RSpec.describe "Multiple Tenant Context Tests", :integration do
  let(:tenant_a) { double("Tenant", subdomain: "tenant_a", name: "Tenant A") }
  let(:tenant_b) { double("Tenant", subdomain: "tenant_b", name: "Tenant B") }
  let(:tenant_c) { double("Tenant", subdomain: "tenant_c", name: "Tenant C") }

  before do
    # Reset context before each test
    Thread.current[:pg_multitenant_current_tenant] = nil
    Thread.current[:pg_multitenant_current_schema] = nil
  end

  describe "context switching between multiple tenants" do
    it "switches between tenants correctly" do
      # Switch to tenant A
      PgMultitenantSchemas::Context.current_tenant = tenant_a
      PgMultitenantSchemas::Context.current_schema = "tenant_a"

      expect(PgMultitenantSchemas::Context.current_schema).to eq("tenant_a")

      # Switch to tenant B
      PgMultitenantSchemas::Context.current_tenant = tenant_b
      PgMultitenantSchemas::Context.current_schema = "tenant_b"

      expect(PgMultitenantSchemas::Context.current_schema).to eq("tenant_b")
    end

    it "maintains thread isolation with multiple tenants" do
      results = {}
      threads = []

      # Create threads for each tenant
      [tenant_a, tenant_b, tenant_c].each_with_index do |tenant, index|
        threads << Thread.new do
          PgMultitenantSchemas::Context.current_tenant = tenant
          PgMultitenantSchemas::Context.current_schema = tenant.subdomain

          sleep 0.01 # Simulate work

          results[index] = PgMultitenantSchemas::Context.current_schema
        end
      end

      threads.each(&:join)

      expect(results[0]).to eq("tenant_a")
      expect(results[1]).to eq("tenant_b")
      expect(results[2]).to eq("tenant_c")
    end
  end
end
