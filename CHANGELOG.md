# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
