# frozen_string_literal: true

module PgMultitenantSchemas
  module UI
    # Mountable Rails engine that exposes the tenant management UI.
    class Engine < ::Rails::Engine
      isolate_namespace PgMultitenantSchemas::UI

      # Tell Rails where this engine's app/ directory lives
      config.root = "#{File.expand_path("../../..", __dir__)}/lib/pg_multitenant_schemas/ui"

      # Fix Zeitwerk inflection: 'ui' directory should map to 'UI' constant
      initializer "pg_multitenant_schemas.ui.inflections", before: :load_config_initializers do
        ActiveSupport::Inflector.inflections(:en) do |inflect|
          inflect.acronym "UI"
        end
      end

      initializer "pg_multitenant_schemas.ui.middleware" do |app|
        # Ensure cookies and session middleware are available for cookie-based schema switching
        # Only in development mode to support schema switching between dashboard and main app
        if ::Rails.env.development?
          # Try to add middleware, but don't fail if it's already there
          begin
            app.config.middleware.insert_before 0, ActionDispatch::Cookies
          rescue StandardError
            # Middleware may already exist, that's fine
          end

          begin
            app.config.middleware.insert_before 1, ActionDispatch::Session::CookieStore, key: "_pg_multitenant_session"
          rescue StandardError
            # Middleware may already exist, that's fine
          end

          begin
            app.config.middleware.insert_before 2, ActionDispatch::Flash
          rescue StandardError
            # Middleware may already exist, that's fine
          end
        end
      end

      initializer "pg_multitenant_schemas.ui.assets" do |app|
        app.config.assets.precompile += %w[pg_multitenant_schemas/ui/application.css] if app.config.respond_to?(:assets)
      end
    end
  end
end
