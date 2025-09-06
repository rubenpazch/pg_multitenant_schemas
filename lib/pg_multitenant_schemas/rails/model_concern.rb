# frozen_string_literal: true

module PgMultitenantSchemas
  module Rails
    # Model concern for tenant callbacks
    module ModelConcern
      extend ActiveSupport::Concern

      included do
        # Add callbacks for schema management
        after_create :create_tenant_schema_callback, if: :should_manage_schema?
        before_destroy :drop_tenant_schema_callback, if: :should_manage_schema?
      end

      def create_tenant_schema_callback
        return unless valid_tenant_for_schema?

        handle_schema_creation
      end

      def drop_tenant_schema_callback
        return unless valid_tenant_for_schema?

        handle_schema_deletion
      end

      protected

      # Override this method to control when schema management should happen
      def should_manage_schema?
        PgMultitenantSchemas.configuration.auto_create_schemas &&
          respond_to?(:subdomain) &&
          subdomain.present?
      end

      private

      # Check if tenant is valid for schema operations
      def valid_tenant_for_schema?
        respond_to?(:subdomain) && subdomain.present?
      end

      # Handle schema creation with error handling
      def handle_schema_creation
        PgMultitenantSchemas::Context.create_tenant_schema(self)
        log_schema_operation("Created schema for tenant '#{subdomain}'")
      rescue PgMultitenantSchemas::SchemaExists
        log_schema_operation("Schema '#{subdomain}' already exists")
      rescue StandardError => e
        handle_schema_error(e, "create")
      end

      # Handle schema deletion with error handling
      def handle_schema_deletion
        PgMultitenantSchemas::Context.drop_tenant_schema(self)
        log_schema_operation("Dropped schema for tenant '#{subdomain}'")
      rescue PgMultitenantSchemas::SchemaNotFound
        log_schema_operation("Schema '#{subdomain}' not found for deletion")
      rescue StandardError => e
        handle_schema_error(e, "drop")
      end

      # Log schema operations
      def log_schema_operation(message)
        Rails.logger.info "PgMultitenantSchemas: #{message}"
      end

      # Handle schema operation errors
      def handle_schema_error(error, operation)
        Rails.logger.error "PgMultitenantSchemas: Failed to #{operation} schema '#{subdomain}': #{error.message}"
        raise error unless development_fallback_enabled?
      end

      # Check if development fallback is enabled
      def development_fallback_enabled?
        PgMultitenantSchemas.configuration.development_fallback && Rails.env.development?
      end

      class_methods do
        # DSL to disable automatic schema management
        def skip_schema_management
          skip_callback :after_create, :create_tenant_schema_callback
          skip_callback :before_destroy, :drop_tenant_schema_callback
        end
      end
    end
  end
end
