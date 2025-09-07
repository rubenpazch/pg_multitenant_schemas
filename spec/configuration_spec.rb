# frozen_string_literal: true

require "spec_helper"

RSpec.describe PgMultitenantSchemas::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.connection_class).to eq("ApplicationRecord")
      expect(config.development_fallback).to be false
      expect(config.auto_create_schemas).to be true
      expect(config.logger).to be_nil
    end
  end

  describe "#connection_class=" do
    it "allows setting connection class" do
      config.connection_class = "CustomConnection"
      expect(config.connection_class).to eq("CustomConnection")
    end
  end

  describe "#development_fallback=" do
    it "allows setting development fallback" do
      config.development_fallback = true
      expect(config.development_fallback).to be true
    end
  end

  describe "#auto_create_schemas=" do
    it "allows setting auto create schemas" do
      config.auto_create_schemas = false
      expect(config.auto_create_schemas).to be false
    end
  end

  describe "#logger=" do
    it "allows setting logger" do
      logger = double("Logger")
      config.logger = logger
      expect(config.logger).to eq(logger)
    end
  end
end
