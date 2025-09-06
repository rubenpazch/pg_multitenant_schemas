# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgMultitenantSchemas do
  describe "error classes" do
    it "defines Error as base class" do
      expect(PgMultitenantSchemas::Error).to be < StandardError
    end

    it "defines ConnectionError" do
      expect(PgMultitenantSchemas::ConnectionError).to be < PgMultitenantSchemas::Error
    end

    it "defines SchemaExists error" do
      expect(PgMultitenantSchemas::SchemaExists).to be < PgMultitenantSchemas::Error
    end

    it "defines SchemaNotFound error" do
      expect(PgMultitenantSchemas::SchemaNotFound).to be < PgMultitenantSchemas::Error
    end

    it "defines ConfigurationError" do
      expect(PgMultitenantSchemas::ConfigurationError).to be < PgMultitenantSchemas::Error
    end

    it "defines TenantNotFound error" do
      expect(PgMultitenantSchemas::TenantNotFound).to be < PgMultitenantSchemas::Error
    end
  end

  describe "configuration" do
    it "provides a configuration object" do
      expect(described_class.configuration).to be_a(PgMultitenantSchemas::Configuration)
    end

    it "allows configuration via block" do
      described_class.configure do |config|
        config.development_fallback = true
      end
      expect(described_class.configuration.development_fallback).to be true
    end
  end
end
