# frozen_string_literal: true

require_relative "lib/pg_multitenant_schemas/version"

Gem::Specification.new do |spec|
  spec.name = "pg_multitenant_schemas"
  spec.version = PgMultitenantSchemas::VERSION
  spec.authors = ["L BYTE EIRL"]
  spec.email = ["info@lbyte.io"]

  spec.summary = "Modern PostgreSQL schema-based multitenancy for Rails"
  spec.description = "A production-ready Ruby gem providing PostgreSQL " \
                     "schema-based multitenancy with automatic tenant resolution, " \
                     "secure isolation, and high performance. Built for Rails 8+ and " \
                     "Ruby 4.0+, tested with latest stable versions. Features comprehensive " \
                     "test coverage (217 tests, 100% passing), complete YARD " \
                     "documentation, and interactive HTML documentation site. Perfect " \
                     "for modern SaaS applications with database-level isolation."
  spec.homepage = "https://github.com/rubenpazch/pg_multitenant_schemas"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 4.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubenpazch.github.io/pg_multitenant_schemas"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["github_repo"] = "ssh://git@github.com/rubenpazch/pg_multitenant_schemas.git"

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

  # Runtime dependencies - Rails 7+ support with Rails 8 optimizations
  spec.add_dependency "activerecord", ">= 7.0", "< 9.0"
  spec.add_dependency "activesupport", ">= 7.0", "< 9.0"
  spec.add_dependency "pg", "~> 1.6"
end
