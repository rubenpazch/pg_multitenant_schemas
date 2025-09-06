# frozen_string_literal: true

module PgMultitenantSchemas
  # Tenant resolution from HTTP requests
  class TenantResolver
    class << self
      # Extract subdomain from host
      def extract_subdomain(host)
        return nil if invalid_host?(host)

        host = clean_host(host)
        parts = host.split(".")
        return nil if parts.length < 2

        subdomain = parts.first.downcase
        return nil if excluded_subdomain?(subdomain, parts)

        subdomain
      end

      private

      # Check if host is invalid for subdomain extraction
      def invalid_host?(host)
        host.blank? || host == "localhost" || host.match?(/\A\d+\.\d+\.\d+\.\d+/)
      end

      # Clean host by removing port
      def clean_host(host)
        host.split(":").first
      end

      # Check if subdomain should be excluded
      def excluded_subdomain?(subdomain, parts)
        # Exclude common subdomains for standard domains (3 parts or fewer)
        # Allow them for complex subdomains (4+ parts like api.company.example.com)
        if parts.length <= 3
          excluded_subdomains = PgMultitenantSchemas.configuration.excluded_subdomains
          return true if excluded_subdomains.include?(subdomain)
        end

        # For exactly 2 parts, also check if second part is a common TLD
        if parts.length == 2
          common_tlds = PgMultitenantSchemas.configuration.common_tlds
          return true if common_tlds.include?(parts.last.downcase)
        end

        false
      end

      public

      # Find tenant by subdomain (only active tenants)
      def find_tenant_by_subdomain(subdomain)
        return nil if subdomain.blank?

        tenant_model = PgMultitenantSchemas.configuration.tenant_model

        # Attempt to find active tenant
        if tenant_model.respond_to?(:active)
          tenant_model.active.find_by(subdomain: subdomain)
        else
          tenant_model.find_by(subdomain: subdomain, status: "active")
        end
      rescue StandardError => e
        Rails.logger.error "PgMultitenantSchemas: Error finding tenant '#{subdomain}': #{e.message}"
        nil
      end

      # Resolve tenant from request
      def resolve_tenant_from_request(request)
        subdomain = extract_subdomain(request.host)
        return nil if subdomain.blank?

        find_tenant_by_subdomain(subdomain)
      end

      # Resolve tenant with fallback options
      def resolve_tenant_with_fallback(request)
        tenant = resolve_tenant_from_request(request)

        # If no tenant found and development fallback is enabled
        if tenant.nil? && PgMultitenantSchemas.configuration.development_fallback && Rails.env.development?
          Rails.logger.info "PgMultitenantSchemas: No tenant found, using development fallback"
          return nil # This will cause switch to default schema
        end

        tenant
      end
    end
  end
end
