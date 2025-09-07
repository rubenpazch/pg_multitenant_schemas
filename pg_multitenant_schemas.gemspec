# frozen_string_literal: true

require_relative "lib/pg_multitenant_schemas/version"

Gem::Specification.new do |spec|
  spec.name = "pg_multitenant_schemas"
  spec.version = PgMultitenantSchemas::VERSION
  spec.authors = ["Ruben Paz"]
  spec.email = ["rubenpazchuspe@outlook.com"]

  spec.summary = "Modern PostgreSQL schema-based multitenancy for Rails 8+ applications"
  spec.description = "A modern Ruby gem that provides PostgreSQL schema-based multitenancy with automatic tenant " \
                     "resolution and schema switching. Built for Rails 8+ and Ruby 3.3+, focusing on security, " \
                     "performance, and developer experience. Perfect for modern SaaS applications requiring " \
                     "secure tenant isolation."
  spec.homepage = "https://github.com/rubenpazch/pg_multitenant_schemas"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile]) ||
        f.end_with?(".gem")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies - Modern Rails only
  spec.add_dependency "activerecord", ">= 8.0", "< 9.0"
  spec.add_dependency "activesupport", ">= 8.0", "< 9.0"
  spec.add_dependency "pg", "~> 1.5"
end
