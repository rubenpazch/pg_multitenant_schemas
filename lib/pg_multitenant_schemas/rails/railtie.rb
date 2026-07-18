# frozen_string_literal: true

module PgMultitenantSchemas
  module Rails
    # Railtie for automatic initialization and integration with Rails applications.
    # Handles schema switcher initialization when ActiveRecord loads.
    class Railtie < ::Rails::Railtie
      initializer "pg_multitenant_schemas.initialize" do |_app|
        # Initialize connection when Rails starts
        ActiveSupport.on_load(:active_record) do
          PgMultitenantSchemas::SchemaSwitcher.initialize_connection
        end
      end

      initializer "pg_multitenant_schemas.middleware" do |app|
        # Add cookies middleware for API-only apps in development
        # Needed for cookie-based schema switching between dashboard and main app
        if ::Rails.env.development?
          # Insert cookies middleware at the beginning
          app.config.middleware.insert_before 0, ActionDispatch::Cookies
          # Session store for reading cookies properly
          app.config.middleware.insert_before 1, ActionDispatch::Session::CookieStore,
                                              key: "_pg_multitenant_session"
          # Flash support for notices/alerts
          app.config.middleware.insert_before 2, ActionDispatch::Flash
        end
      end

      initializer "pg_multitenant_schemas.controller_integration" do
        # Automatically extend ApplicationController with ControllerConcern
        ActiveSupport.on_load(:action_controller) do
          include PgMultitenantSchemas::Rails::ControllerConcern
        end
      end

      initializer "pg_multitenant_schemas.ui.routes" do |app|
        app.routes.append do
          mount PgMultitenantSchemas::UI::Engine, at: "/pg_multitenant_schemas"
        end
      end

      # Add rake tasks
      rake_tasks do
        # Load all task files
        Dir[File.expand_path("../tasks/*.rake", __dir__)].each do |task_file|
          load task_file
        end
      end

      # Add generators
      generators do
        require_relative "generators/install_generator"
        require_relative "generators/tenant_migration_generator"
      end
    end
  end
end
