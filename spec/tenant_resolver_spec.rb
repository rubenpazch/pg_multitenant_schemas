# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgMultitenantSchemas::TenantResolver do
  describe ".extract_subdomain" do
    it "extracts subdomain from valid host" do
      expect(described_class.extract_subdomain("demo.example.com")).to eq("demo")
    end

    it "returns nil for localhost" do
      expect(described_class.extract_subdomain("localhost")).to be_nil
    end

    it "returns nil for IP addresses" do
      expect(described_class.extract_subdomain("192.168.1.1")).to be_nil
    end

    it "handles hosts with ports" do
      expect(described_class.extract_subdomain("demo.example.com:3000")).to eq("demo")
    end

    it "returns nil for excluded subdomains" do
      expect(described_class.extract_subdomain("www.example.com")).to be_nil
      expect(described_class.extract_subdomain("api.example.com")).to be_nil
    end

    it "returns nil for common TLDs" do
      expect(described_class.extract_subdomain("example.com")).to be_nil
    end

    it "handles complex subdomains" do
      expect(described_class.extract_subdomain("api.company.example.com")).to eq("api")
    end

    it "returns nil for blank hosts" do
      expect(described_class.extract_subdomain("")).to be_nil
      expect(described_class.extract_subdomain(nil)).to be_nil
    end
  end

  describe ".find_tenant_by_subdomain" do
    it "responds to find_tenant_by_subdomain method" do
      expect(described_class).to respond_to(:find_tenant_by_subdomain)
    end
  end

  describe ".resolve_tenant_from_request" do
    it "responds to resolve_tenant_from_request method" do
      expect(described_class).to respond_to(:resolve_tenant_from_request)
    end
  end
end
