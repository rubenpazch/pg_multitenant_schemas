# frozen_string_literal: true

# PgMultitenantSchemas provides PostgreSQL schema-based multitenancy functionality.
module PgMultitenantSchemas
  # Configuration class for PgMultitenantSchemas gem settings.
  # Manages tenant resolution, schema switching behavior, and Rails integration options.
  class Configuration
    attr_accessor :tenant_model_class, :default_schema, :development_fallback,
                  :excluded_subdomains, :common_tlds, :auto_create_schemas,
                  :connection_class, :logger

    def initialize
      @tenant_model_class = "Tenant"
      @default_schema = "public"
      @development_fallback = false
      @excluded_subdomains = %w[www api admin mail ftp blog support help docs]
      @common_tlds = %w[com org net edu gov mil int co uk ca au de fr jp cn]
      @auto_create_schemas = true
      @connection_class = "ActiveRecord::Base"
      @logger = nil
    end

    def tenant_model
      @tenant_model ||= tenant_model_class.constantize
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
