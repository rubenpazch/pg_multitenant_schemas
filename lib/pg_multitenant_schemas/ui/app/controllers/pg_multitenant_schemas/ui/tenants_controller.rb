# frozen_string_literal: true

module PgMultitenantSchemas
  module UI
    # Controller backing the UI engine for listing and managing tenants and schemas.
    class TenantsController < ActionController::Base
      layout "pg_multitenant_schemas/ui/application"
      skip_forgery_protection only: :destroy

      before_action :load_tenant_model

      def index
        @tenants = tenant_model.all.order(:subdomain)
        @schemas = load_available_schemas
        @current_schema = resolve_selected_schema
      end

      def new
        @tenant = tenant_model.new
      end

      def create
        @tenant = tenant_model.new(tenant_params)

        if @tenant.save
          PgMultitenantSchemas::Migrator.setup_tenant(@tenant.subdomain, verbose: false)
          redirect_to "/pg_multitenant_schemas/tenants",
                      notice: "Tenant '#{@tenant.subdomain}' created and schema provisioned."
        else
          render :new, status: :unprocessable_entity
        end
      rescue StandardError => e
        @tenant&.destroy if @tenant&.persisted?
        redirect_to "/pg_multitenant_schemas/tenants",
                    alert: "Failed to provision schema: #{e.message}"
      end

      def destroy
        @tenant = tenant_model.find(params[:id])
        schema = @tenant.subdomain

        @tenant.destroy
        PgMultitenantSchemas::SchemaSwitcher.drop_schema(schema)
        redirect_to "/pg_multitenant_schemas/tenants",
                    notice: "Tenant '#{schema}' and its schema deleted."
      rescue StandardError => e
        redirect_to "/pg_multitenant_schemas/tenants",
                    alert: "Error deleting tenant: #{e.message}"
      end

      def migrate
        @tenant = tenant_model.find(params[:id])
        result = PgMultitenantSchemas::Migrator.migrate_tenant(@tenant.subdomain, verbose: false)
        status = result[:status] == :success ? "notice" : "alert"
        msg = result[:message] || "Migration completed."
        redirect_to "/pg_multitenant_schemas/tenants", status => msg
      rescue StandardError => e
        redirect_to "/pg_multitenant_schemas/tenants", alert: "Migration failed: #{e.message}"
      end

      def migrate_all
        results = PgMultitenantSchemas::Migrator.migrate_all(verbose: false)
        failed = results.count { |r| r[:status] == :error }
        if failed.zero?
          redirect_to "/pg_multitenant_schemas/tenants",
                      notice: "All #{results.size} tenant schemas migrated successfully."
        else
          redirect_to "/pg_multitenant_schemas/tenants",
                      alert: "#{failed} of #{results.size} migrations failed."
        end
      end

      def migration_status
        @tenant = tenant_model.find(params[:id])
        statuses = PgMultitenantSchemas::Migrator.migration_status(verbose: false)
        @status = statuses.find { |s| s[:schema] == @tenant.subdomain } || {}
        render :migration_status
      end

      def switch
        schema = params[:schema].to_s.strip
        return redirect_invalid_schema(schema) unless PgMultitenantSchemas::SchemaSwitcher.schema_exists?(schema)

        PgMultitenantSchemas::Context.current_schema = schema
        store_schema_in_session_and_cookies(schema)
        redirect_to "/pg_multitenant_schemas/tenants",
                    notice: "Switched active context to schema '#{schema}'."
      end

      private

      def load_available_schemas
        PgMultitenantSchemas::SchemaSwitcher.list_schemas
      rescue StandardError
        []
      end

      def resolve_selected_schema
        selected = (session[:pg_multitenant_selected_schema] || cookies[:pg_multitenant_selected_schema]).to_s.strip
        return selected if selected.present? && load_available_schemas.include?(selected)

        PgMultitenantSchemas::Context.current_schema
      end

      def store_schema_in_session_and_cookies(schema)
        session[:pg_multitenant_selected_schema] = schema
        cookies[:pg_multitenant_selected_schema] = {
          value: schema,
          expires: 24.hours.from_now,
          path: "/",
          same_site: :lax,
          http_only: false
        }
      end

      def redirect_invalid_schema(schema)
        redirect_to "/pg_multitenant_schemas/tenants",
                    alert: "Schema '#{schema}' does not exist."
      end

      def load_tenant_model
        @tenant_model_name = PgMultitenantSchemas.configuration.tenant_model_class
      end

      def tenant_model = @tenant_model_name.constantize

      def tenant_params = params.require(:tenant).permit(:subdomain, :name, :status)
    end
  end
end
