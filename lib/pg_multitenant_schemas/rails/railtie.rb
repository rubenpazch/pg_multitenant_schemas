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

      # Add rake tasks
      rake_tasks do
        load File.expand_path("../tasks/pg_multitenant_schemas.rake", __dir__)
      end

      # Add generators
      generators do
        require_relative "generators/install_generator"
        require_relative "generators/tenant_migration_generator"
      end
    end
  end
end
