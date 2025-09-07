# Errors - Exception Handling and Custom Errors

**File**: `lib/pg_multitenant_schemas/errors.rb`

## 📋 Overview

The `Errors` module defines custom exception classes for the PG Multitenant Schemas gem, providing specific error types for different failure scenarios and better error handling throughout the application.

## 🎯 Purpose

- **Specific Exceptions**: Different error types for different failure scenarios
- **Better Debugging**: Clear error messages with context information
- **Error Handling**: Structured error handling throughout the gem
- **User Experience**: Meaningful error messages for developers

## 🔧 Exception Classes

### Core Exceptions

```ruby
module PgMultitenantSchemas
  # Base exception class for all gem-related errors
  class Error < StandardError; end
  
  # Configuration-related errors
  class ConfigurationError < Error; end
  
  # Schema operation failures
  class SchemaError < Error; end
  
  # Tenant resolution failures
  class TenantNotFoundError < Error; end
  
  # Migration-related errors
  class MigrationError < Error; end
  
  # Connection-related errors
  class ConnectionError < Error; end
end
```

### Detailed Exception Definitions

#### Base Error Class

```ruby
class Error < StandardError
  attr_reader :context, :tenant, :schema
  
  def initialize(message, context: nil, tenant: nil, schema: nil)
    @context = context
    @tenant = tenant
    @schema = schema
    super(message)
  end
  
  def to_h
    {
      error: self.class.name,
      message: message,
      context: context,
      tenant: tenant&.to_s,
      schema: schema
    }
  end
end
```

#### Configuration Errors

```ruby
class ConfigurationError < Error
  def self.missing_tenant_model
    new("Tenant model not configured. Set config.tenant_model in initializer.")
  end
  
  def self.invalid_connection_class(class_name)
    new("Invalid connection class: #{class_name}. Class not found or not an ActiveRecord class.")
  end
  
  def self.missing_default_schema
    new("Default schema not configured. Set config.default_schema in initializer.")
  end
end
```

#### Schema Errors

```ruby
class SchemaError < Error
  def self.schema_not_found(schema_name)
    new("Schema '#{schema_name}' does not exist", schema: schema_name)
  end
  
  def self.schema_already_exists(schema_name)
    new("Schema '#{schema_name}' already exists", schema: schema_name)
  end
  
  def self.invalid_schema_name(schema_name)
    new("Invalid schema name: '#{schema_name}'. Schema names must be valid PostgreSQL identifiers.", schema: schema_name)
  end
  
  def self.cannot_drop_public_schema
    new("Cannot drop the public schema", schema: 'public')
  end
  
  def self.schema_switch_failed(schema_name, original_error)
    new("Failed to switch to schema '#{schema_name}': #{original_error.message}", schema: schema_name)
  end
end
```

#### Tenant Errors

```ruby
class TenantNotFoundError < Error
  def self.by_subdomain(subdomain)
    new("Tenant not found with subdomain: #{subdomain}", context: { subdomain: subdomain })
  end
  
  def self.by_domain(domain)
    new("Tenant not found with domain: #{domain}", context: { domain: domain })
  end
  
  def self.by_id(tenant_id)
    new("Tenant not found with ID: #{tenant_id}", context: { tenant_id: tenant_id })
  end
  
  def self.from_request(request_info)
    new("Could not resolve tenant from request", context: request_info)
  end
end
```

#### Migration Errors

```ruby
class MigrationError < Error
  def self.migration_failed(schema_name, migration_version, original_error)
    new(
      "Migration #{migration_version} failed for schema #{schema_name}: #{original_error.message}",
      schema: schema_name,
      context: { migration_version: migration_version, original_error: original_error.class.name }
    )
  end
  
  def self.rollback_failed(schema_name, steps, original_error)
    new(
      "Failed to rollback #{steps} steps for schema #{schema_name}: #{original_error.message}",
      schema: schema_name,
      context: { rollback_steps: steps, original_error: original_error.class.name }
    )
  end
  
  def self.no_pending_migrations(schema_name)
    new("No pending migrations for schema: #{schema_name}", schema: schema_name)
  end
end
```

#### Connection Errors

```ruby
class ConnectionError < Error
  def self.connection_not_available
    new("Database connection not available")
  end
  
  def self.invalid_connection_config(config)
    new("Invalid connection configuration: #{config}")
  end
  
  def self.connection_timeout
    new("Database connection timeout")
  end
end
```

## 🔄 Usage Patterns

### Error Handling in Components

#### Schema Switcher Error Handling

```ruby
module PgMultitenantSchemas
  class SchemaSwitcher
    def self.switch_schema(schema_name)
      validate_schema_name!(schema_name)
      
      connection.execute("SET search_path TO #{schema_name}, public")
    rescue PG::UndefinedObject => e
      raise SchemaError.schema_not_found(schema_name)
    rescue StandardError => e
      raise SchemaError.schema_switch_failed(schema_name, e)
    end
    
    def self.create_schema(schema_name)
      validate_schema_name!(schema_name)
      
      connection.execute("CREATE SCHEMA IF NOT EXISTS #{schema_name}")
    rescue PG::DuplicateSchema => e
      raise SchemaError.schema_already_exists(schema_name)
    rescue StandardError => e
      raise SchemaError.new("Failed to create schema #{schema_name}: #{e.message}", schema: schema_name)
    end
    
    private
    
    def self.validate_schema_name!(schema_name)
      if schema_name.blank? || !schema_name.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
        raise SchemaError.invalid_schema_name(schema_name)
      end
    end
  end
end
```

#### Tenant Resolver Error Handling

```ruby
module PgMultitenantSchemas
  class TenantResolver
    def self.resolve_from_request(request)
      subdomain = extract_subdomain(request)
      return nil if subdomain.blank?
      
      tenant = tenant_model.find_by(subdomain: subdomain)
      
      unless tenant
        raise TenantNotFoundError.by_subdomain(subdomain)
      end
      
      tenant
    rescue ActiveRecord::ConnectionNotEstablished => e
      raise ConnectionError.connection_not_available
    rescue StandardError => e
      request_info = {
        host: request.host,
        subdomain: subdomain,
        user_agent: request.user_agent
      }
      raise TenantNotFoundError.from_request(request_info)
    end
  end
end
```

#### Migrator Error Handling

```ruby
module PgMultitenantSchemas
  class Migrator
    def self.migrate_tenant(schema_name)
      puts "📦 Migrating schema: #{schema_name}"
      
      Context.with_tenant(schema_name) do
        ActiveRecord::Tasks::DatabaseTasks.migrate
      end
      
      puts "  ✅ Completed migration for #{schema_name}"
    rescue StandardError => e
      puts "  ❌ Error migrating #{schema_name}: #{e.message}"
      
      # Re-raise as MigrationError with context
      raise MigrationError.migration_failed(schema_name, 'latest', e)
    end
  end
end
```

### Application-Level Error Handling

#### Controller Error Handling

```ruby
class ApplicationController < ActionController::Base
  rescue_from PgMultitenantSchemas::TenantNotFoundError, with: :handle_tenant_not_found
  rescue_from PgMultitenantSchemas::SchemaError, with: :handle_schema_error
  rescue_from PgMultitenantSchemas::Error, with: :handle_multitenant_error
  
  private
  
  def handle_tenant_not_found(error)
    Rails.logger.warn "Tenant not found: #{error.message}"
    
    respond_to do |format|
      format.html { redirect_to tenant_selection_path, alert: "Please select a valid tenant" }
      format.json { render json: error.to_h, status: :not_found }
      format.xml { render xml: error.to_h, status: :not_found }
    end
  end
  
  def handle_schema_error(error)
    Rails.logger.error "Schema error: #{error.message}"
    
    respond_to do |format|
      format.html { redirect_to root_path, alert: "A database error occurred" }
      format.json { render json: { error: "Database error" }, status: :internal_server_error }
    end
  end
  
  def handle_multitenant_error(error)
    Rails.logger.error "Multitenant error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    respond_to do |format|
      format.html { redirect_to root_path, alert: "An error occurred" }
      format.json { render json: { error: "Internal error" }, status: :internal_server_error }
    end
  end
end
```

#### API Error Handling

```ruby
class Api::BaseController < ActionController::API
  rescue_from PgMultitenantSchemas::TenantNotFoundError do |error|
    render json: {
      error: 'tenant_not_found',
      message: error.message,
      context: error.context
    }, status: :not_found
  end
  
  rescue_from PgMultitenantSchemas::SchemaError do |error|
    render json: {
      error: 'schema_error',
      message: error.message,
      schema: error.schema
    }, status: :unprocessable_entity
  end
  
  rescue_from PgMultitenantSchemas::MigrationError do |error|
    render json: {
      error: 'migration_error',
      message: 'Database migration required',
      schema: error.schema
    }, status: :service_unavailable
  end
  
  rescue_from PgMultitenantSchemas::Error do |error|
    render json: {
      error: 'multitenant_error',
      message: error.message
    }, status: :internal_server_error
  end
end
```

#### Background Job Error Handling

```ruby
class TenantJob < ApplicationJob
  retry_on PgMultitenantSchemas::ConnectionError, wait: 30.seconds, attempts: 3
  discard_on PgMultitenantSchemas::TenantNotFoundError
  
  rescue_from PgMultitenantSchemas::SchemaError do |error|
    Rails.logger.error "Schema error in job: #{error.message}"
    # Notify administrators
    AdminNotifier.schema_error(error).deliver_now
  end
  
  def perform(tenant_id, *args)
    tenant = Tenant.find(tenant_id)
    
    PgMultitenantSchemas::Context.with_tenant(tenant) do
      process_tenant_work(*args)
    end
  rescue PgMultitenantSchemas::TenantNotFoundError => e
    Rails.logger.error "Tenant #{tenant_id} not found for job"
    # Don't retry for missing tenants
    raise e
  rescue PgMultitenantSchemas::MigrationError => e
    Rails.logger.error "Migration required for tenant #{tenant_id}"
    # Schedule migration and retry
    TenantMigrationJob.perform_later(tenant_id)
    raise e
  end
end
```

## 🔍 Error Monitoring and Debugging

### Error Logging Enhancement

```ruby
module ErrorLogging
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    def with_error_context(context = {})
      yield
    rescue PgMultitenantSchemas::Error => e
      enhanced_error = e.class.new(
        e.message,
        context: e.context&.merge(context) || context,
        tenant: e.tenant,
        schema: e.schema
      )
      
      Rails.logger.error "#{e.class.name}: #{e.message}"
      Rails.logger.error "Context: #{enhanced_error.context}"
      Rails.logger.error "Tenant: #{enhanced_error.tenant}" if enhanced_error.tenant
      Rails.logger.error "Schema: #{enhanced_error.schema}" if enhanced_error.schema
      
      raise enhanced_error
    end
  end
end
```

### Error Reporting Integration

```ruby
# For services like Sentry, Rollbar, etc.
module ErrorReporting
  def self.report_multitenant_error(error, extra_context = {})
    return unless error.is_a?(PgMultitenantSchemas::Error)
    
    Sentry.capture_exception(error) do |scope|
      scope.set_tag('component', 'pg_multitenant_schemas')
      scope.set_tag('tenant', error.tenant) if error.tenant
      scope.set_tag('schema', error.schema) if error.schema
      
      scope.set_context('multitenant', {
        context: error.context,
        tenant: error.tenant,
        schema: error.schema
      }.merge(extra_context))
    end
  end
end

# Usage in error handlers
rescue PgMultitenantSchemas::Error => e
  ErrorReporting.report_multitenant_error(e, { controller: self.class.name, action: action_name })
  raise e
```

## 🚨 Error Prevention Best Practices

### Validation and Guards

```ruby
# Validate configuration on startup
PgMultitenantSchemas.configure do |config|
  config.validate_on_startup = true
end

# Guard clauses in critical methods
def switch_to_tenant(tenant)
  raise ArgumentError, "Tenant cannot be nil" if tenant.nil?
  raise PgMultitenantSchemas::TenantNotFoundError.by_id(tenant.id) unless tenant.persisted?
  
  # Proceed with tenant switching
end
```

### Error Recovery

```ruby
# Automatic recovery for transient errors
module AutoRecovery
  def with_retry(max_attempts: 3, backoff: 1.second)
    attempts = 0
    
    begin
      yield
    rescue PgMultitenantSchemas::ConnectionError => e
      attempts += 1
      
      if attempts < max_attempts
        Rails.logger.warn "Connection error (attempt #{attempts}/#{max_attempts}): #{e.message}"
        sleep(backoff * attempts)
        retry
      else
        raise e
      end
    end
  end
end
```

## 🔗 Related Components

- **[Configuration](configuration.md)**: Configuration validation and errors
- **[SchemaSwitcher](schema_switcher.md)**: Schema operation error handling
- **[Context](context.md)**: Context management error scenarios
- **[TenantResolver](tenant_resolver.md)**: Tenant resolution error handling
- **[Migrator](migrator.md)**: Migration error management

## 📝 Examples

See [examples/error_handling.rb](../examples/) for comprehensive error handling patterns and recovery strategies.
