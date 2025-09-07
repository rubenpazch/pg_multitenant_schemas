# Tenant Resolver - Tenant Identification and Resolution

**File**: `lib/pg_multitenant_schemas/tenant_resolver.rb`

## 📋 Overview

The `TenantResolver` is responsible for identifying and resolving tenant information from various sources like HTTP requests, subdomains, headers, or custom logic. It provides flexible tenant identification strategies for different application architectures.

## 🎯 Purpose

- **Request Analysis**: Extract tenant information from HTTP requests
- **Flexible Resolution**: Support multiple tenant identification strategies
- **Caching**: Efficient tenant lookup with caching mechanisms
- **Error Handling**: Graceful handling of tenant resolution failures

## 🔧 Key Methods

### Core Resolution

```ruby
# Resolve tenant from request
TenantResolver.resolve_from_request(request)

# Resolve tenant by subdomain
TenantResolver.resolve_by_subdomain('acme')

# Resolve tenant by custom header
TenantResolver.resolve_by_header(request, 'X-Tenant-ID')

# Resolve tenant by domain
TenantResolver.resolve_by_domain('acme.myapp.com')
```

### Configuration and Caching

```ruby
# Configure resolution strategy
TenantResolver.configure do |config|
  config.strategy = :subdomain
  config.cache_enabled = true
  config.cache_ttl = 5.minutes
end

# Clear tenant cache
TenantResolver.clear_cache!

# Get cached tenant
TenantResolver.cached_tenant(identifier)
```

## 🏗️ Implementation Details

### Resolution Strategies

#### Subdomain Strategy

```ruby
def resolve_by_subdomain(subdomain)
  return nil if subdomain.blank?
  
  tenant_model.find_by(subdomain: subdomain)
end

# Usage in controller
def resolve_tenant_from_request
  subdomain = request.subdomain
  TenantResolver.resolve_by_subdomain(subdomain)
end
```

#### Domain Strategy

```ruby
def resolve_by_domain(domain)
  return nil if domain.blank?
  
  # Extract domain from full host
  domain = extract_domain(domain) if domain.include?('.')
  
  tenant_model.find_by(domain: domain)
end
```

#### Header Strategy

```ruby
def resolve_by_header(request, header_name = 'X-Tenant-ID')
  tenant_id = request.headers[header_name]
  return nil if tenant_id.blank?
  
  tenant_model.find(tenant_id)
rescue ActiveRecord::RecordNotFound
  nil
end
```

#### Custom Strategy

```ruby
def resolve_by_custom_logic(request)
  # Implement custom tenant resolution logic
  # Examples:
  # - Path-based: /tenants/acme/dashboard
  # - JWT token: Extract tenant from JWT
  # - Database lookup: Complex tenant hierarchies
  
  case request.path
  when /^\/tenants\/(\w+)/
    subdomain = $1
    resolve_by_subdomain(subdomain)
  else
    resolve_by_subdomain(request.subdomain)
  end
end
```

### Caching Implementation

```ruby
class TenantResolver
  class << self
    def cached_tenant(identifier)
      return resolve_tenant(identifier) unless cache_enabled?
      
      Rails.cache.fetch(cache_key(identifier), expires_in: cache_ttl) do
        resolve_tenant(identifier)
      end
    end
    
    private
    
    def cache_key(identifier)
      "pg_multitenant:tenant:#{identifier}"
    end
    
    def cache_enabled?
      configuration.cache_enabled
    end
    
    def cache_ttl
      configuration.cache_ttl || 5.minutes
    end
  end
end
```

## 🔄 Usage Patterns

### Rails Controller Integration

```ruby
class ApplicationController < ActionController::Base
  before_action :resolve_and_set_tenant
  
  private
  
  def resolve_and_set_tenant
    @current_tenant = TenantResolver.resolve_from_request(request)
    
    if @current_tenant
      PgMultitenantSchemas::Context.switch_to_tenant(@current_tenant)
    else
      handle_tenant_not_found
    end
  end
  
  def handle_tenant_not_found
    # Handle tenant resolution failure
    case request.format
    when :json
      render json: { error: 'Tenant not found' }, status: :not_found
    else
      redirect_to tenant_selection_path
    end
  end
end
```

### API Applications

```ruby
class ApiController < ActionController::API
  before_action :authenticate_and_resolve_tenant
  
  private
  
  def authenticate_and_resolve_tenant
    # Extract tenant from JWT token
    token = request.headers['Authorization']&.split(' ')&.last
    payload = JWT.decode(token, Rails.application.secret_key_base).first
    
    tenant_id = payload['tenant_id']
    @current_tenant = TenantResolver.resolve_by_id(tenant_id)
    
    if @current_tenant
      PgMultitenantSchemas::Context.switch_to_tenant(@current_tenant)
    else
      render json: { error: 'Invalid tenant' }, status: :unauthorized
    end
  rescue JWT::DecodeError
    render json: { error: 'Invalid token' }, status: :unauthorized
  end
end
```

### Background Jobs

```ruby
class TenantJob < ApplicationJob
  def perform(tenant_identifier, *args)
    tenant = TenantResolver.resolve_by_subdomain(tenant_identifier)
    
    if tenant
      PgMultitenantSchemas::Context.with_tenant(tenant) do
        process_tenant_specific_task(*args)
      end
    else
      Rails.logger.error "Tenant not found: #{tenant_identifier}"
    end
  end
end
```

### Multi-Strategy Resolution

```ruby
class FlexibleTenantResolver < TenantResolver
  def self.resolve_from_request(request)
    # Try multiple strategies in order
    strategies = [:header, :subdomain, :path, :session]
    
    strategies.each do |strategy|
      tenant = try_strategy(strategy, request)
      return tenant if tenant
    end
    
    nil
  end
  
  private
  
  def self.try_strategy(strategy, request)
    case strategy
    when :header
      resolve_by_header(request, 'X-Tenant-ID')
    when :subdomain
      resolve_by_subdomain(request.subdomain)
    when :path
      resolve_by_path(request.path)
    when :session
      resolve_by_session(request.session)
    end
  rescue StandardError => e
    Rails.logger.warn "Tenant resolution strategy #{strategy} failed: #{e.message}"
    nil
  end
end
```

## 🎛️ Configuration Options

### Basic Configuration

```ruby
TenantResolver.configure do |config|
  config.strategy = :subdomain  # Default resolution strategy
  config.cache_enabled = true   # Enable tenant caching
  config.cache_ttl = 5.minutes  # Cache time-to-live
  config.fallback_strategy = :session  # Fallback if primary fails
end
```

### Advanced Configuration

```ruby
TenantResolver.configure do |config|
  # Resolution strategies
  config.primary_strategy = :subdomain
  config.fallback_strategies = [:header, :session]
  
  # Caching
  config.cache_enabled = Rails.env.production?
  config.cache_ttl = 10.minutes
  config.cache_namespace = 'tenant_resolver'
  
  # Error handling
  config.raise_on_not_found = false
  config.log_resolution_failures = true
  
  # Custom resolvers
  config.custom_resolvers = {
    api: ApiTenantResolver,
    admin: AdminTenantResolver
  }
end
```

## 🚨 Important Considerations

### Performance

- **Caching**: Enable caching for production environments
- **Database Queries**: Minimize tenant lookup queries
- **Index Optimization**: Ensure tenant lookup fields are indexed

### Security

- **Input Validation**: Validate tenant identifiers to prevent injection
- **Access Control**: Verify user has access to resolved tenant
- **Audit Logging**: Log tenant resolution for security auditing

### Error Handling

- **Graceful Degradation**: Handle tenant resolution failures gracefully
- **Fallback Strategies**: Implement fallback resolution methods
- **User Experience**: Provide clear error messages for tenant issues

## 🔍 Debugging and Monitoring

### Debug Tenant Resolution

```ruby
# Add logging to tenant resolution
module TenantResolutionLogger
  def resolve_from_request(request)
    Rails.logger.debug "Resolving tenant from: #{request.host}"
    
    tenant = super(request)
    
    if tenant
      Rails.logger.debug "Resolved tenant: #{tenant.subdomain}"
    else
      Rails.logger.warn "Failed to resolve tenant from: #{request.host}"
    end
    
    tenant
  end
end

TenantResolver.prepend(TenantResolutionLogger)
```

### Monitor Resolution Performance

```ruby
# Track resolution time
def resolve_with_timing(identifier)
  start_time = Time.current
  
  tenant = resolve_without_timing(identifier)
  
  duration = Time.current - start_time
  Rails.logger.info "Tenant resolution took #{duration * 1000}ms"
  
  tenant
end

alias_method :resolve_without_timing, :resolve_tenant
alias_method :resolve_tenant, :resolve_with_timing
```

### Cache Statistics

```ruby
# Monitor cache hit rates
class TenantCacheMonitor
  def self.cache_stats
    {
      hits: Rails.cache.fetch('tenant_cache_hits', raw: true) || 0,
      misses: Rails.cache.fetch('tenant_cache_misses', raw: true) || 0,
      hit_rate: calculate_hit_rate
    }
  end
  
  def self.increment_hits
    Rails.cache.increment('tenant_cache_hits', 1, raw: true, expires_in: 1.day)
  end
  
  def self.increment_misses
    Rails.cache.increment('tenant_cache_misses', 1, raw: true, expires_in: 1.day)
  end
end
```

## 🔗 Related Components

- **[Context](context.md)**: Uses resolved tenant for context switching
- **[Configuration](configuration.md)**: Tenant model and resolution configuration
- **[Rails Integration](rails_integration.md)**: Controller and middleware integration
- **[Errors](errors.md)**: Tenant resolution error handling

## 📝 Examples

See [examples/tenant_resolution.rb](../examples/) for complete tenant resolution patterns and [Rails integration examples](../examples/rails_integration/) for framework-specific implementations.
