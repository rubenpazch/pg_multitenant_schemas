# frozen_string_literal: true

module PgMultitenantSchemas
  # Thread-safe tenant context management
  class Context
    class << self
      def current_tenant
        Thread.current[:pg_multitenant_current_tenant]
      end

      def current_tenant=(tenant)
        Thread.current[:pg_multitenant_current_tenant] = tenant
      end

      def current_schema
        Thread.current[:pg_multitenant_current_schema] || PgMultitenantSchemas.configuration.default_schema
      end

      def current_schema=(schema_name)
        Thread.current[:pg_multitenant_current_schema] = schema_name
      end

      def reset!
        Thread.current[:pg_multitenant_current_tenant] = nil
        Thread.current[:pg_multitenant_current_schema] = nil
        switch_to_schema(PgMultitenantSchemas.configuration.default_schema)
      end

      def switch_to_schema(schema_name)
        schema_name = PgMultitenantSchemas.configuration.default_schema if schema_name.blank?
        SchemaSwitcher.switch_schema(schema_name)
        self.current_schema = schema_name
      end

      def switch_to_tenant(tenant)
        if tenant
          schema_name = tenant.respond_to?(:subdomain) ? tenant.subdomain : tenant.to_s
          switch_to_schema(schema_name)
          self.current_tenant = tenant
        else
          switch_to_schema(PgMultitenantSchemas.configuration.default_schema)
          self.current_tenant = nil
        end
      end

      # Execute block within tenant context
      def with_tenant(tenant_or_schema)
        schema_name, tenant = extract_schema_and_tenant(tenant_or_schema)
        previous_tenant = current_tenant
        previous_schema = current_schema

        begin
          switch_to_schema(schema_name)
          self.current_tenant = tenant
          yield if block_given?
        ensure
          restore_previous_context(previous_tenant, previous_schema)
        end
      end

      private

      # Extract schema name and tenant object from input
      def extract_schema_and_tenant(tenant_or_schema)
        if tenant_or_schema.respond_to?(:subdomain)
          [tenant_or_schema.subdomain, tenant_or_schema]
        else
          [tenant_or_schema.to_s, nil]
        end
      end

      # Restore the previous tenant context
      def restore_previous_context(previous_tenant, previous_schema)
        restore_schema = if previous_tenant.respond_to?(:subdomain)
                           previous_tenant.subdomain
                         else
                           previous_schema
                         end
        switch_to_schema(restore_schema)
        self.current_tenant = previous_tenant
      end

      public

      # Create new tenant schema
      def create_tenant_schema(tenant_or_schema)
        schema_name = if tenant_or_schema.respond_to?(:subdomain)
                        tenant_or_schema.subdomain
                      else
                        tenant_or_schema.to_s
                      end
        SchemaSwitcher.create_schema(schema_name)
      end

      # Drop tenant schema
      def drop_tenant_schema(tenant_or_schema, cascade: true)
        schema_name = if tenant_or_schema.respond_to?(:subdomain)
                        tenant_or_schema.subdomain
                      else
                        tenant_or_schema.to_s
                      end
        SchemaSwitcher.drop_schema(schema_name, cascade: cascade)
      end
    end
  end
end
