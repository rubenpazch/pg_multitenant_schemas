# Rails Integration - Framework Components

**Files**: `lib/pg_multitenant_schemas/rails/`

## 📋 Overview

The Rails integration components provide seamless integration with the Ruby on Rails framework, including controller concerns, model concerns, and automatic configuration through Railtie.

## 🎯 Purpose

- **Framework Integration**: Native Rails framework support
- **Controller Concerns**: Automatic tenant resolution in controllers
- **Model Concerns**: Tenant-aware model behavior
- **Automatic Setup**: Zero-configuration Rails integration
- **Middleware Support**: Request-level tenant handling

## 🔧 Core Components

### 1. Controller Concern (`controller_concern.rb`)

Provides automatic tenant resolution and context switching for Rails controllers.

```ruby
module PgMultitenantSchemas
  module ControllerConcern
    extend ActiveSupport::Concern
    
    included do
      before_action :set_tenant_context
      around_action :with_tenant_context
    end
    
    private
    
    def set_tenant_context
      @current_tenant = resolve_tenant_from_request
    end
    
    def with_tenant_context
      if @current_tenant
        PgMultitenantSchemas::Context.with_tenant(@current_tenant) do
          yield
        end
      else
        yield
      end
    end
  end
end
```

### 2. Model Concern (`model_concern.rb`)

Adds tenant-aware behavior to ActiveRecord models.

```ruby
module PgMultitenantSchemas
  module ModelConcern
    extend ActiveSupport::Concern
    
    included do
      scope :current_tenant, -> { 
        # Already scoped by schema context
        all 
      }
    end
    
    class_methods do
      def tenant_scoped?
        true
      end
      
      def create_for_tenant!(tenant, attributes = {})
        PgMultitenantSchemas::Context.with_tenant(tenant) do
          create!(attributes)
        end
      end
    end
  end
end
```

### 3. Railtie (`railtie.rb`)

Automatic Rails integration and configuration.

```ruby
module PgMultitenantSchemas
  class Railtie < Rails::Railtie
    initializer "pg_multitenant_schemas.load_tasks" do
      load "pg_multitenant_schemas/tasks/pg_multitenant_schemas.rake"
    end
    
    initializer "pg_multitenant_schemas.active_record" do
      ActiveSupport.on_load(:active_record) do
        # Auto-include model concern for ApplicationRecord
        include PgMultitenantSchemas::ModelConcern if self == ApplicationRecord
      end
    end
  end
end
```

## 🔄 Usage Patterns

### Controller Integration

#### Basic Setup

```ruby
class ApplicationController < ActionController::Base
  include PgMultitenantSchemas::ControllerConcern
  
  private
  
  def resolve_tenant_from_request
    # Custom tenant resolution logic
    subdomain = request.subdomain
    Tenant.find_by(subdomain: subdomain) if subdomain.present?
  end
end
```

#### Advanced Controller Setup

```ruby
class ApplicationController < ActionController::Base
  include PgMultitenantSchemas::ControllerConcern
  
  before_action :authenticate_user!
  before_action :ensure_tenant_access
  
  private
  
  def resolve_tenant_from_request
    # Multi-strategy tenant resolution
    tenant = resolve_by_subdomain || resolve_by_header || resolve_by_session
    
    # Ensure user has access to tenant
    tenant if tenant && current_user&.has_access_to?(tenant)
  end
  
  def resolve_by_subdomain
    subdomain = request.subdomain
    Tenant.active.find_by(subdomain: subdomain) if subdomain.present?
  end
  
  def resolve_by_header
    tenant_id = request.headers['X-Tenant-ID']
    Tenant.find(tenant_id) if tenant_id.present?
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  def resolve_by_session
    tenant_id = session[:tenant_id]
    Tenant.find(tenant_id) if tenant_id.present?
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  def ensure_tenant_access
    unless @current_tenant
      respond_to do |format|
        format.html { redirect_to tenant_selection_path }
        format.json { render json: { error: 'Tenant required' }, status: :unauthorized }
      end
    end
  end
end
```

#### API Controller Integration

```ruby
class Api::BaseController < ActionController::API
  include PgMultitenantSchemas::ControllerConcern
  
  before_action :authenticate_api_request
  
  private
  
  def resolve_tenant_from_request
    # Extract tenant from JWT or API key
    if @api_token
      @api_token.tenant
    elsif @jwt_payload
      Tenant.find(@jwt_payload['tenant_id'])
    end
  end
  
  def authenticate_api_request
    token = request.headers['Authorization']&.split(' ')&.last
    
    if token.present?
      @api_token = ApiToken.active.find_by(token: token)
      @jwt_payload = decode_jwt(token) if @api_token.nil?
    end
    
    head :unauthorized unless @api_token || @jwt_payload
  end
end
```

### Model Integration

#### Basic Model Setup

```ruby
class ApplicationRecord < ActiveRecord::Base
  include PgMultitenantSchemas::ModelConcern
  
  self.abstract_class = true
end

# All models automatically inherit tenant awareness
class User < ApplicationRecord
  # Automatically tenant-scoped through schema context
end

class Order < ApplicationRecord
  belongs_to :user
  
  # Custom tenant-aware scopes
  scope :recent, -> { where('created_at > ?', 1.week.ago) }
  scope :for_tenant, ->(tenant) {
    PgMultitenantSchemas::Context.with_tenant(tenant) { all }
  }
end
```

#### Advanced Model Patterns

```ruby
class TenantAwareRecord < ApplicationRecord
  include PgMultitenantSchemas::ModelConcern
  
  self.abstract_class = true
  
  # Callbacks for tenant operations
  before_create :set_tenant_metadata
  after_create :notify_tenant_activity
  
  class_methods do
    def create_for_all_tenants!(attributes = {})
      results = []
      
      Tenant.active.find_each do |tenant|
        result = create_for_tenant!(tenant, attributes)
        results << result
      end
      
      results
    end
    
    def migrate_to_tenant(source_tenant, target_tenant, record_id)
      source_record = nil
      
      # Get record from source tenant
      PgMultitenantSchemas::Context.with_tenant(source_tenant) do
        source_record = find(record_id)
      end
      
      # Create in target tenant
      PgMultitenantSchemas::Context.with_tenant(target_tenant) do
        create!(source_record.attributes.except('id', 'created_at'))
      end
    end
  end
  
  private
  
  def set_tenant_metadata
    if PgMultitenantSchemas::Context.current_tenant
      self.tenant_id = PgMultitenantSchemas::Context.current_tenant.id
    end
  end
  
  def notify_tenant_activity
    TenantActivityJob.perform_later(
      PgMultitenantSchemas::Context.current_tenant&.id,
      self.class.name,
      'created'
    )
  end
end
```

### Background Job Integration

```ruby
class TenantJob < ApplicationJob
  include PgMultitenantSchemas::ControllerConcern
  
  def perform(tenant_id, *args)
    tenant = Tenant.find(tenant_id)
    
    PgMultitenantSchemas::Context.with_tenant(tenant) do
      process_tenant_specific_work(*args)
    end
  end
  
  private
  
  def process_tenant_specific_work(*args)
    # All database operations automatically scoped to tenant
    users = User.all
    orders = Order.pending
    
    # Process tenant-specific data
  end
end
```

## 🎛️ Configuration and Customization

### Custom Controller Concern

```ruby
module CustomTenantController
  extend ActiveSupport::Concern
  
  include PgMultitenantSchemas::ControllerConcern
  
  included do
    before_action :log_tenant_access
    after_action :track_tenant_activity
  end
  
  private
  
  def log_tenant_access
    if @current_tenant
      Rails.logger.info "Tenant access: #{@current_tenant.subdomain} by #{current_user&.email}"
    end
  end
  
  def track_tenant_activity
    TenantAnalytics.track_request(
      tenant: @current_tenant,
      user: current_user,
      action: "#{controller_name}##{action_name}",
      ip: request.remote_ip
    )
  end
end
```

### Custom Model Behavior

```ruby
module CustomTenantModel
  extend ActiveSupport::Concern
  
  include PgMultitenantSchemas::ModelConcern
  
  included do
    # Add audit fields
    before_save :set_tenant_audit_fields
    
    # Add tenant validation
    validate :ensure_tenant_context
  end
  
  class_methods do
    def tenant_report(tenant)
      PgMultitenantSchemas::Context.with_tenant(tenant) do
        {
          total_records: count,
          recent_records: where('created_at > ?', 1.week.ago).count,
          tenant_name: tenant.name
        }
      end
    end
  end
  
  private
  
  def set_tenant_audit_fields
    current_tenant = PgMultitenantSchemas::Context.current_tenant
    
    if current_tenant
      self.tenant_context_id = current_tenant.id
      self.tenant_context_name = current_tenant.subdomain
    end
  end
  
  def ensure_tenant_context
    unless PgMultitenantSchemas::Context.current_tenant
      errors.add(:base, 'Must be created within tenant context')
    end
  end
end
```

### Middleware Integration

```ruby
class TenantMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    request = ActionDispatch::Request.new(env)
    
    # Resolve tenant early in request cycle
    tenant = resolve_tenant(request)
    
    if tenant
      PgMultitenantSchemas::Context.with_tenant(tenant) do
        @app.call(env)
      end
    else
      handle_no_tenant(env)
    end
  end
  
  private
  
  def resolve_tenant(request)
    # Implementation depends on tenant resolution strategy
    subdomain = request.subdomain
    Tenant.find_by(subdomain: subdomain) if subdomain.present?
  end
  
  def handle_no_tenant(env)
    # Return appropriate response for missing tenant
    [404, {'Content-Type' => 'text/plain'}, ['Tenant not found']]
  end
end
```

## 🚨 Important Considerations

### Performance

- **Connection Pooling**: Ensure proper connection pool sizing for multi-tenant load
- **Query Optimization**: Schema switching doesn't add query overhead
- **Caching**: Implement tenant-aware caching strategies

### Security

- **Tenant Isolation**: Verify complete data isolation between tenants
- **Access Control**: Implement proper tenant access controls
- **Audit Logging**: Log tenant access and data changes

### Error Handling

- **Graceful Degradation**: Handle tenant resolution failures gracefully
- **Error Reporting**: Include tenant context in error reports
- **Fallback Strategies**: Implement fallback for tenant resolution failures

## 🔗 Related Components

- **[Context](context.md)**: Core tenant context management used by Rails components
- **[TenantResolver](tenant_resolver.md)**: Tenant resolution strategies for controllers
- **[Configuration](configuration.md)**: Rails integration configuration options
- **[Migrator](migrator.md)**: Database migration management for Rails apps

## 📝 Examples

See [examples/rails_integration/](../examples/rails_integration/) for complete Rails integration examples including:
- Controller setup patterns
- Model integration examples
- Background job handling
- Middleware implementation
- API authentication strategies
