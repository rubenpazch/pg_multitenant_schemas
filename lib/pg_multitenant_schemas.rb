# frozen_string_literal: true

# PgMultitenantSchemas provides modern PostgreSQL schema-based multitenancy functionality.
#
# Built for Rails 8+ and Ruby 3.3+, it allows switching between different PostgreSQL schemas
# to achieve secure tenant isolation while maintaining high performance and developer experience.
#
# @example Basic usage
#   tenant = Tenant.find(1)
#   PgMultitenantSchemas.switch_to_tenant(tenant)
#   # All queries now use tenant's schema
#
# @example Block-based context
#   PgMultitenantSchemas.with_tenant(tenant) do
#     User.all  # Queries tenant's schema
#   end
#
# @see PgMultitenantSchemas::Context
# @see PgMultitenantSchemas::SchemaSwitcher
# @see PgMultitenantSchemas::Migrator
module PgMultitenantSchemas
  require "active_support/core_ext/module/delegation"
  require "active_support/core_ext/object/blank"
  require_relative "pg_multitenant_schemas/version"
  require_relative "pg_multitenant_schemas/errors"
  require_relative "pg_multitenant_schemas/configuration"
  require_relative "pg_multitenant_schemas/context"
  require_relative "pg_multitenant_schemas/schema_switcher"
  require_relative "pg_multitenant_schemas/tenant_resolver"
  require_relative "pg_multitenant_schemas/migrator"

  # Rails integration (Rails 8+ required)
  if defined?(Rails)
    require_relative "pg_multitenant_schemas/rails/controller_concern"
    require_relative "pg_multitenant_schemas/rails/model_concern"
    require_relative "pg_multitenant_schemas/rails/railtie"
    require_relative "pg_multitenant_schemas/ui/engine"
  end

  class << self
    # Get the current tenant object
    #
    # @return [Object, nil] The current tenant or nil if not set
    # @see Context.current_tenant
    attr_accessor :current_tenant

    # Set the current tenant object
    #
    # @param tenant [Object] The tenant to set as current
    # @see Context.current_tenant=

    # Get the current tenant schema name
    #
    # @return [String] The current schema name
    # @see Context.current_schema
    attr_accessor :current_schema

    # Set the current tenant schema name
    #
    # @param schema [String] The schema name to set as current
    # @see Context.current_schema=

    # Reset the current tenant context
    #
    # @return [void]
    # @see Context.reset!
    def reset!
      Context.reset!
    end

    # Switch to a specific schema
    #
    # @param schema_name [String] The schema name to switch to
    # @return [void]
    # @see Context.switch_to_schema
    def switch_to_schema(schema_name)
      Context.switch_to_schema(schema_name)
    end

    # Switch to a specific tenant's schema
    #
    # @param tenant [Object, String] The tenant object or schema name
    # @return [void]
    # @see Context.switch_to_tenant
    def switch_to_tenant(tenant)
      Context.switch_to_tenant(tenant)
    end

    # Execute a block within a tenant context
    #
    # @param tenant_or_schema [Object, String] The tenant object or schema name
    # @yield Executes the given block in the tenant's schema context
    # @return [Object] The return value of the block
    # @see Context.with_tenant
    def with_tenant(tenant_or_schema, &)
      Context.with_tenant(tenant_or_schema, &)
    end

    # Create a new tenant schema
    #
    # @param tenant_or_schema [Object, String] The tenant object or schema name
    # @return [void]
    # @see Context.create_tenant_schema
    def create_tenant_schema(tenant_or_schema)
      Context.create_tenant_schema(tenant_or_schema)
    end

    # Drop a tenant schema
    #
    # @param tenant_or_schema [Object, String] The tenant object or schema name
    # @param cascade [Boolean] Whether to drop dependent objects (default: true)
    # @return [void]
    # @see Context.drop_tenant_schema
    def drop_tenant_schema(tenant_or_schema, cascade: true)
      Context.drop_tenant_schema(tenant_or_schema, cascade: cascade)
    end

    # Extract tenant subdomain from a hostname
    #
    # @param hostname [String] The hostname to extract from
    # @return [String, nil] The extracted subdomain or nil
    # @see TenantResolver.extract_subdomain
    def extract_subdomain(hostname)
      TenantResolver.extract_subdomain(hostname)
    end

    # Find a tenant by subdomain
    #
    # @param subdomain [String] The subdomain to search for
    # @return [Object, nil] The tenant object or nil if not found
    # @see TenantResolver.find_tenant_by_subdomain
    def find_tenant_by_subdomain(subdomain)
      TenantResolver.find_tenant_by_subdomain(subdomain)
    end

    # Resolve tenant from Rails request
    #
    # @param request [ActionDispatch::Request] The Rails request object
    # @return [Object, nil] The tenant object or nil if not resolved
    # @see TenantResolver.resolve_tenant_from_request
    def resolve_tenant_from_request(request)
      TenantResolver.resolve_tenant_from_request(request)
    end
  end

  # Get the current configuration
  #
  # @return [Configuration] The gem configuration object
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Configure the gem
  #
  # @yield Yields the configuration object for configuration
  # @example
  #   PgMultitenantSchemas.configure do |config|
  #     config.tenant_model_class = 'Tenant'
  #     config.default_schema = 'public'
  #   end
  def self.configure
    yield(configuration) if block_given?
  end
end
