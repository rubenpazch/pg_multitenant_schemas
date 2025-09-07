# frozen_string_literal: true

# frozen_string_li# PgMultitenantSchemas provides modern PostgreSQL schema-based multitenancy functionality.
# Built for Rails 8+ and Ruby 3.4+, it allows switching between different PostgreSQL schemas
# to achieve secure tenant isolation while maintaining high performance and developer experience.al: true

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
end

# PgMultitenantSchemas provides modern PostgreSQL schema-based multitenancy functionality.
# Built for Rails 8+ and Ruby 3.3+, it allows switching between different PostgreSQL schemas
# to achieve secure tenant isolation while maintaining high performance and developer experience.
module PgMultitenantSchemas
  class << self
    # Delegate common methods to Context for convenience
    delegate :current_tenant, :current_tenant=, :current_schema, :current_schema=,
             :reset!, :switch_to_schema, :switch_to_tenant, :with_tenant,
             :create_tenant_schema, :drop_tenant_schema, to: :"PgMultitenantSchemas::Context"

    # Delegate tenant resolution to TenantResolver
    delegate :extract_subdomain, :find_tenant_by_subdomain, :resolve_tenant_from_request,
             to: :"PgMultitenantSchemas::TenantResolver"
  end
end
