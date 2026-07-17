# frozen_string_literal: true

module PgMultitenantSchemas
  # Thread-safe tenant context management
  #
  # The Context class manages the current tenant and schema in a thread-safe manner
  # using Thread.current storage. This ensures proper isolation in multi-threaded
  # environments like Rails servers.
  #
  # @example Get current schema
  #   PgMultitenantSchemas::Context.current_schema #=> "tenant_123"
  #
  # @example Switch to tenant context
  #   tenant = Tenant.find(1)
  #   PgMultitenantSchemas::Context.switch_to_tenant(tenant)
  #
  # @example Use block-based context
  #   PgMultitenantSchemas::Context.with_tenant(tenant) do
  #     User.all  # Queries tenant's schema
  #   end
  class Context
    class << self
      # Get the current tenant object
      #
      # @return [Object, nil] The current tenant or nil if no tenant context is set
      def current_tenant
        Thread.current[:pg_multitenant_current_tenant]
      end

      # Set the current tenant object
      #
      # @param tenant [Object] The tenant object to set as current
      # @return [Object] The tenant object
      def current_tenant=(tenant)
        Thread.current[:pg_multitenant_current_tenant] = tenant
      end

      # Get the current tenant schema name
      #
      # @return [String] The current schema name or default schema if not set
      # @example
      #   PgMultitenantSchemas::Context.current_schema #=> "tenant_123"
      def current_schema
        Thread.current[:pg_multitenant_current_schema] || PgMultitenantSchemas.configuration.default_schema
      end

      # Set the current tenant schema name
      #
      # @param schema_name [String] The schema name to set as current
      # @return [String] The schema name
      def current_schema=(schema_name)
        Thread.current[:pg_multitenant_current_schema] = schema_name
      end

      # Reset the current tenant context to default
      #
      # Clears both tenant and schema context and restores the default schema
      #
      # @return [void]
      # @example
      #   PgMultitenantSchemas::Context.reset!
      def reset!
        Thread.current[:pg_multitenant_current_tenant] = nil
        Thread.current[:pg_multitenant_current_schema] = nil
        switch_to_schema(PgMultitenantSchemas.configuration.default_schema)
      end

      # Switch to a specific schema
      #
      # @param schema_name [String] The schema name to switch to
      # @return [void]
      # @example
      #   PgMultitenantSchemas::Context.switch_to_schema('tenant_123')
      def switch_to_schema(schema_name)
        schema_name = PgMultitenantSchemas.configuration.default_schema if schema_name.blank?
        SchemaSwitcher.switch_schema(schema_name)
        self.current_schema = schema_name
      end

      # Switch to a specific tenant's schema
      #
      # @param tenant [Object, String] The tenant object (must respond to :subdomain) or schema name
      # @return [void]
      # @example With tenant object
      #   tenant = Tenant.find(1)
      #   PgMultitenantSchemas::Context.switch_to_tenant(tenant)
      # @example With schema name
      #   PgMultitenantSchemas::Context.switch_to_tenant('tenant_123')
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

      # Execute a block within a tenant context
      #
      # All database queries within the block will be executed in the tenant's schema.
      # The previous context is restored after the block completes, even if an error occurs.
      #
      # @param tenant_or_schema [Object, String] The tenant object or schema name
      # @yield Executes the given block in the tenant's schema context
      # @return [Object] The return value of the block
      # @example With tenant object
      #   tenant = Tenant.find(1)
      #   PgMultitenantSchemas::Context.with_tenant(tenant) do
      #     User.all  # Queries tenant's schema
      #   end
      # @example With schema name
      #   PgMultitenantSchemas::Context.with_tenant('tenant_123') do
      #     Order.create!(status: 'pending')
      #   end
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

      # Create a new PostgreSQL schema for a tenant
      #
      # @param tenant_or_schema [Object, String] The tenant object or schema name
      # @return [void]
      # @raise [ArgumentError] if schema name is blank
      # @example With tenant object
      #   tenant = Tenant.create!(subdomain: 'acme')
      #   PgMultitenantSchemas::Context.create_tenant_schema(tenant)
      # @example With schema name
      #   PgMultitenantSchemas::Context.create_tenant_schema('tenant_123')
      def create_tenant_schema(tenant_or_schema)
        schema_name = if tenant_or_schema.respond_to?(:subdomain)
                        tenant_or_schema.subdomain
                      else
                        tenant_or_schema.to_s
                      end
        SchemaSwitcher.create_schema(schema_name)
      end

      # Drop a PostgreSQL schema for a tenant
      #
      # @param tenant_or_schema [Object, String] The tenant object or schema name
      # @param cascade [Boolean] Whether to drop dependent objects (default: true)
      # @return [void]
      # @raise [ArgumentError] if schema name is blank
      # @example With tenant object
      #   tenant = Tenant.find(1)
      #   PgMultitenantSchemas::Context.drop_tenant_schema(tenant)
      # @example With cascade option
      #   PgMultitenantSchemas::Context.drop_tenant_schema('old_tenant', cascade: true)
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
