# frozen_string_literal: true

require "rails/generators"

module PgMultitenantSchemas
  module Generators
    # Generates the initializer used to configure PgMultitenantSchemas in a Rails app.
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a PgMultitenantSchemas initializer in your Rails app"

      def create_initializer
        create_file "config/initializers/pg_multitenant_schemas.rb", <<~RUBY
          PgMultitenantSchemas.configure do |config|
            config.connection_class = "ApplicationRecord"
            config.tenant_model_class = "Tenant"
            config.default_schema = "public"
            config.excluded_subdomains = ["www", "api", "admin"]
            config.development_fallback = true
            config.auto_create_schemas = true
          end
        RUBY
      end
    end
  end
end
