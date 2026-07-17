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
        # Try to resolve tenant from cookie/session first (for development mode)
        tenant = resolve_from_cookie_fallback(request)
        
        # If no tenant from cookie/session, use normal resolution
        if tenant.nil?
          tenant = PgMultitenantSchemas::TenantResolver.resolve_tenant_with_fallback(request)
        end
        
        switch_to_tenant(tenant)
      rescue StandardError => e
        handle_tenant_resolution_error(e)
      end

      private

      # Try to resolve tenant from cookie/session-based schema (if available)
      def resolve_from_cookie_fallback(request)
        return nil unless should_use_cookie_fallback?

        begin
          schema = nil
          
          # Try reading from session first (most reliable for cross-request persistence)
          if respond_to?(:session) && session.present?
            schema = session[:pg_multitenant_selected_schema]
          end
          
          # If not in session, try multiple ways to get cookies
          if schema.nil?
            if request.respond_to?(:cookie_jar)
              schema = request.cookie_jar[:pg_multitenant_selected_schema]
            elsif request.respond_to?(:cookies)
              schema = request.cookies[:pg_multitenant_selected_schema]
            elsif respond_to?(:cookies)
              schema = cookies[:pg_multitenant_selected_schema]
            else
              # Fallback: parse the raw HTTP_COOKIE header
              cookie_header = request.env['HTTP_COOKIE']
              if cookie_header.present?
                # Parse "key1=value1; key2=value2; ..." format
                schema = cookie_header.split('; ').find { |c| c.start_with?('pg_multitenant_selected_schema=') }&.split('=')&.last
              end
            end
          end
          
          return nil unless schema.present?
          
          unless PgMultitenantSchemas::SchemaSwitcher.schema_exists?(schema)
            return nil
          end
          
          # Set schema directly from cookie
          PgMultitenantSchemas::Context.current_schema = schema
          @current_tenant = nil
          
          # Return a virtual tenant object (we don't need to query the database)
          OpenStruct.new(subdomain: schema, schema: schema)
        rescue StandardError => e
          ::Rails.logger.debug "PgMultitenantSchemas: resolve_from_cookie_fallback failed: #{e.class} #{e.message}"
          nil
        end
      end

      # Check if we should try cookie-based resolution
      def should_use_cookie_fallback?
        return false unless PgMultitenantSchemas.configuration.development_fallback
        return false unless ::Rails.env.development?
        
        # If we reach here, we should attempt cookie-based resolution
        true
      end

      def reset_tenant_context
        @current_tenant = nil
        PgMultitenantSchemas::Context.reset!
      rescue StandardError => e
        # Silently ignore errors during context reset
      end

      protected

      # Override this method in controllers that shouldn't use tenant resolution
      def skip_tenant_resolution?
        false
      end

      # Override this method to customize error handling
      def handle_tenant_resolution_error(error)
        ::Rails.logger.error "PgMultitenantSchemas: Tenant resolution failed: #{error.message}"

        raise error unless PgMultitenantSchemas.configuration.development_fallback && ::Rails.env.development?

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
