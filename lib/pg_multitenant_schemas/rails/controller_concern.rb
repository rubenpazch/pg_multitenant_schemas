# frozen_string_literal: true

module PgMultitenantSchemas
  module Rails
    # Controller concern for Rails integration
    module ControllerConcern
      extend ActiveSupport::Concern

      included do
        # Add callback hooks that can be overridden
        before_action :resolve_tenant_context, unless: :skip_tenant_resolution?
        after_action :reset_tenant_context, unless: :skip_tenant_resolution?

        # Make current tenant available to views
        helper_method :current_tenant, :current_schema if respond_to?(:helper_method)
      end

      # Instance methods
      def current_tenant
        @current_tenant || PgMultitenantSchemas::Context.current_tenant
      end

      def current_schema
        PgMultitenantSchemas::Context.current_schema
      end

      def switch_to_tenant(tenant)
        @current_tenant = tenant
        PgMultitenantSchemas::Context.switch_to_tenant(tenant)
      end

      def resolve_tenant_context
        tenant = PgMultitenantSchemas::TenantResolver.resolve_tenant_with_fallback(request)
        switch_to_tenant(tenant)
      rescue StandardError => e
        handle_tenant_resolution_error(e)
      end

      def reset_tenant_context
        @current_tenant = nil
        PgMultitenantSchemas::Context.reset!
      rescue StandardError => e
        Rails.logger.error "PgMultitenantSchemas: Failed to reset tenant context: #{e.message}"
        # Don't raise - this is cleanup code
      end

      protected

      # Override this method in controllers that shouldn't use tenant resolution
      def skip_tenant_resolution?
        false
      end

      # Override this method to customize error handling
      def handle_tenant_resolution_error(error)
        Rails.logger.error "PgMultitenantSchemas: Tenant resolution failed: #{error.message}"

        raise error unless PgMultitenantSchemas.configuration.development_fallback && Rails.env.development?

        switch_to_tenant(nil) # Fall back to default schema in development
      end

      # Class methods
      class_methods do
        # DSL to skip tenant resolution for specific actions
        def skip_tenant_resolution(options = {})
          skip_before_action :resolve_tenant_context, options
          skip_after_action :reset_tenant_context, options
        end
      end
    end
  end
end
