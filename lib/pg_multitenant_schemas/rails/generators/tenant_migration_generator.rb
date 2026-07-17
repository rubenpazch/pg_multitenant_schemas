# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module PgMultitenantSchemas
  module Generators
    # Generates a migration for adding a tenant to a schema.
    class TenantMigrationGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates a migration to add a tenant to a schema"

      argument :tenant_name, type: :string, banner: "TENANT_NAME"

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration
        migration_template(
          "tenant_migration.rb.erb",
          "db/migrate/create_#{tenant_name}_schema.rb"
        )
      end
    end
  end
end
