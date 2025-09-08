# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.2] - 2025-09-07

### 🔧 **Developer Experience & Testing**
- **NEW: Local Workflow Testing**: Complete solution for testing GitHub Actions locally before push
- **NEW: Pre-Push Validation**: `pre-push-check.sh` script validates CI components locally  
- **NEW: GitHub Actions Testing**: `act` tool integration with configuration files
- **NEW: Validation Scripts**: `validate-github-commands.sh` and `test-github-setup.sh`

### 🚀 **CI/CD Improvements**
- **FIXED: GitHub Actions Permissions**: Resolved permission issues with release workflow
- **FIXED: RSpec Command**: Corrected `--exclude-pattern` usage for unit test isolation
- **IMPROVED: Release Automation**: Enhanced release workflow with proper bot identity
- **IMPROVED: Documentation**: Comprehensive guides for CI/CD setup and troubleshooting

### 📚 **Documentation Enhancements**
- **NEW: Local Testing Guide**: `TESTING_LOCALLY.md` and `LOCAL_TESTING_SUMMARY.md`
- **NEW: CI/CD Setup Guide**: `docs/github_actions_setup.md` with step-by-step instructions
- **NEW: Permissions Fix Guide**: `docs/github_actions_permissions_fix.md`
- **NEW: Workflow Testing Guide**: `docs/local_workflow_testing.md`
- **IMPROVED: Core Documentation**: Updated `docs/README.md` with local testing references

### 🧪 **Testing Infrastructure**
- **ENHANCED: RuboCop Compliance**: Fixed all code style violations across test suite
- **ENHANCED: Test Organization**: Improved test structure and mocking patterns
- **ENHANCED: Integration Testing**: Better PostgreSQL integration test support
- **ENHANCED: Security Auditing**: Bundle audit integration in CI pipeline

### 🔧 **Configuration Files**
- **NEW: `.actrc`**: Configuration for local GitHub Actions testing
- **NEW: `.env.local.example`**: Template for local environment variables
- **IMPROVED: `.gitignore`**: Added local testing files to ignore list

## [0.2.1] - 2025-09-06

### 🚀 **Migration System Overhaul** 
- **NEW: Automated Migration Management**: Complete migration system for multi-tenant schemas
- **NEW: PgMultitenantSchemas::Migrator**: Comprehensive migration management class
- **NEW: Simplified Rake Tasks**: Modern `tenants:*` namespace with intuitive commands
- **NEW: Bulk Operations**: Single-command migration across all tenant schemas
- **NEW: Enhanced Status Reporting**: Detailed migration status with progress indicators

### ✨ **Enhanced Features**
- **Automated Tenant Setup**: `setup_tenant()` creates schema + runs migrations
- **Migration Status Tracking**: Real-time status across all tenant schemas  
- **Error Resilience**: Graceful error handling per tenant during bulk operations
- **Tenant Creation Workflow**: `create_tenant_with_schema()` for complete tenant setup
- **Rollback Support**: Individual tenant rollback capabilities

### 🔧 **Developer Experience**
- **Intuitive Commands**: `rails tenants:migrate`, `rails tenants:status`, `rails tenants:create`
- **Progress Feedback**: Visual progress indicators during migration operations
- **Safety Features**: Confirmation prompts for destructive operations
- **Legacy Compatibility**: Deprecated old commands with migration path
- **Example Scripts**: Complete workflow documentation and examples

## [0.2.0] - 2025-09-06

### 🚀 **BREAKING CHANGES**
- **Modernized for Rails 8+ and Ruby 3.4+**: Removed backward compatibility
- **Simplified API**: Removed dual API support for cleaner codebase
- **Rails 8+ Only**: Updated dependencies to require ActiveRecord >= 8.0
- **Ruby 3.2+ Required**: Minimum Ruby version increased from 3.1.0 to 3.2.0

### ✨ **Added**
- Modern Ruby 3.3+ features and performance optimizations
- Enhanced configuration defaults for Rails 8+ applications
- Improved error messages and developer experience

### 🔧 **Changed**
- Simplified `SchemaSwitcher` API (removed connection parameter overloads)
- Updated default connection class to `ApplicationRecord`
- Enhanced excluded subdomains and TLD lists
- Automatic Rails logger integration

### 🗑️ **Removed**
- Backward compatibility layers
- Dual API support (old conn parameter methods)
- Legacy Rails version compatibility code
- Ruby < 3.3 support

## [0.1.3] - 2025-09-03

### Added
- Rails 8 compatibility with database connection handling
- Dual API support for backward compatibility
- Comprehensive Rails integration with concerns
- Thread-safe context management
- Advanced tenant resolution from subdomains
- Automatic schema creation and cleanup
- Extensive test coverage (86 tests)

### Changed
- Updated dependencies to latest versions
- Improved error handling and validation
- Enhanced documentation and README
- Fixed delegation issues in main module

### Fixed
- Database connection compatibility for Rails 8
- Module loading and delegation issues
- API parameter detection logic
- Thread isolation improvements

## [0.1.2] - 2025-09-02

### Fixed
- Critical API bug where Context called SchemaSwitcher with incorrect parameters
- Module delegation to use fully qualified class names

## [0.1.1] - 2025-09-02

### Added
- Documentation for all core classes
- Development dependencies management

## [0.1.0] - 2025-09-01

### Added
- Initial release
- Basic schema switching functionality
- PostgreSQL multitenancy support

[Unreleased]: https://github.com/rubenpazch/pg_multitenant_schemas/compare/v0.2.2...HEAD
[0.2.2]: https://github.com/rubenpazch/pg_multitenant_schemas/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/rubenpazch/pg_multitenant_schemas/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/rubenpazch/pg_multitenant_schemas/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/rubenpazch/pg_multitenant_schemas/releases/tag/v0.1.0
