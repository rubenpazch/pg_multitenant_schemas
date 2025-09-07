# frozen_string_literal: true

# Rails Controller Integration Examples
# Demonstrates various controller patterns for multi-tenant applications

# Example 1: Basic Application Controller Setup
# Provides tenant resolution and access control for Rails applications
class ApplicationController < ActionController::Base
  include PgMultitenantSchemas::ControllerConcern

  protect_from_forgery with: :exception
  before_action :authenticate_user!
  before_action :ensure_tenant_access

  protected

  # Custom tenant resolution from request
  def resolve_tenant_from_request
    resolve_by_subdomain || resolve_by_domain || resolve_by_user_preference
  end

  private

  def resolve_by_subdomain
    return nil unless request.subdomain.present?

    Tenant.active.find_by(subdomain: request.subdomain)
  end

  def resolve_by_domain
    return nil unless request.domain.present?

    Tenant.active.find_by(domain: request.host)
  end

  def resolve_by_user_preference
    return nil unless user_signed_in? && current_user.current_tenant_id.present?

    current_user.tenants.find_by(id: current_user.current_tenant_id)
  end

  def tenant_access_valid?
    @current_tenant && current_user&.has_access_to?(@current_tenant)
  end

  def ensure_tenant_access
    return handle_missing_tenant unless @current_tenant
    return handle_access_denied unless tenant_access_valid?

    true
  end

  def handle_missing_tenant
    respond_to do |format|
      format.html { redirect_to tenant_selection_path, alert: "Please select a tenant" }
      format.json { render json: { error: "Tenant required" }, status: :unauthorized }
    end
  end

  def handle_access_denied
    respond_to do |format|
      format.html { redirect_to root_path, alert: "Access denied" }
      format.json { render json: { error: "Access denied" }, status: :forbidden }
    end
  end

  # Helper method to access current tenant in views
  helper_method :current_tenant
  attr_reader :current_tenant

  # Custom error handling for tenant-related errors
  rescue_from PgMultitenantSchemas::TenantNotFoundError do |error|
    Rails.logger.warn "Tenant not found: #{error.message}"

    respond_to do |format|
      format.html { redirect_to tenant_selection_path, alert: "Tenant not found" }
      format.json { render json: { error: "Tenant not found" }, status: :not_found }
    end
  end

  rescue_from PgMultitenantSchemas::SchemaError do |error|
    Rails.logger.error "Schema error: #{error.message}"

    respond_to do |format|
      format.html { redirect_to root_path, alert: "A database error occurred" }
      format.json { render json: { error: "Database error" }, status: :internal_server_error }
    end
  end
end

# Example 2: Admin Controller with Multi-Tenant Management
module Admin
  # Controller for managing tenants in admin interface
  # Allows administrators to view, manage, and switch between tenant contexts
  class TenantsController < Admin::BaseController
    # Admin controllers might need to switch between tenants

    def index
      # List all tenants (admin view, not tenant-scoped)
      @tenants = Tenant.includes(:users, :subscriptions).order(:name)
    end

    def show
      @tenant = Tenant.find(params[:id])

      # Get tenant-specific statistics
      @stats = PgMultitenantSchemas::Context.with_tenant(@tenant) do
        {
          users_count: User.count,
          orders_count: Order.count,
          revenue: Order.sum(:total),
          last_activity: User.maximum(:last_sign_in_at)
        }
      end
    end

    def switch
      @tenant = Tenant.find(params[:id])

      # Allow admin to switch to tenant for support
      if current_user.admin? && @tenant
        session[:admin_impersonating_tenant] = @tenant.id
        redirect_to root_path, notice: "Switched to tenant: #{@tenant.name}"
      else
        redirect_to admin_tenants_path, alert: "Access denied"
      end
    end

    def stop_impersonation
      session.delete(:admin_impersonating_tenant)
      redirect_to admin_tenants_path, notice: "Stopped tenant impersonation"
    end

    private

    def resolve_tenant_from_request
      # Admin impersonation takes precedence
      if session[:admin_impersonating_tenant] && current_user&.admin?
        return Tenant.find_by(id: session[:admin_impersonating_tenant])
      end

      # Fall back to normal resolution
      super
    end
  end
end

# Example 3: API Controller with JWT-based Tenant Resolution
module Api
  module V1
    # Base controller for API endpoints with tenant resolution
    # Supports JWT and API key authentication with tenant context
    class BaseController < ActionController::API
      include PgMultitenantSchemas::ControllerConcern

      before_action :authenticate_api_request

      protected

      def resolve_tenant_from_request
        # Extract tenant from JWT payload
        return @jwt_payload["tenant"] if @jwt_payload&.key?("tenant")

        # Extract from API key
        return @api_key.tenant if @api_key&.tenant

        # Extract from header
        tenant_id = request.headers["X-Tenant-ID"]
        return Tenant.find(tenant_id) if tenant_id.present?

        nil
      rescue ActiveRecord::RecordNotFound
        nil
      end

      private

      def authenticate_api_request
        token = extract_token_from_header

        if token.present?
          @jwt_payload = decode_jwt_token(token)
          @api_key = ApiKey.active.find_by(token: token) if @jwt_payload.nil?
        end

        return if @jwt_payload || @api_key

        render json: { error: "Unauthorized" }, status: :unauthorized
      end

      def extract_token_from_header
        auth_header = request.headers["Authorization"]
        auth_header&.split&.last if auth_header&.start_with?("Bearer ")
      end

      def decode_jwt_token(token)
        JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256").first
      rescue JWT::DecodeError, JWT::ExpiredSignature
        nil
      end

      # API-specific error handling
      rescue_from PgMultitenantSchemas::TenantNotFoundError do |error|
        render json: {
          error: "tenant_not_found",
          message: error.message,
          code: "TENANT_NOT_FOUND"
        }, status: :not_found
      end

      rescue_from PgMultitenantSchemas::SchemaError do |_error|
        render json: {
          error: "schema_error",
          message: "Database schema error",
          code: "SCHEMA_ERROR"
        }, status: :internal_server_error
      end
    end
  end
end

# Example 4: Background Job Controller Integration
class JobsController < ApplicationController
  def create
    # Enqueue job with current tenant context
    ProcessDataJob.perform_later(
      current_tenant.id,
      params[:data_type],
      params[:options]
    )

    render json: {
      message: "Job enqueued successfully",
      tenant: current_tenant.subdomain
    }
  end

  def status
    # Check job status within tenant context
    job_id = params[:job_id]

    # Job status checking happens in tenant context
    job_status = Rails.cache.read("job_status:#{current_tenant.id}:#{job_id}")

    render json: {
      job_id: job_id,
      status: job_status || "not_found",
      tenant: current_tenant.subdomain
    }
  end
end

# Example 5: Multi-Strategy Tenant Resolution Controller
class FlexibleController < ApplicationController
  protected

  def resolve_tenant_from_request
    # Try multiple resolution strategies in order
    strategies = %i[
      resolve_by_custom_header
      resolve_by_subdomain
      resolve_by_path_parameter
      resolve_by_user_preference
      resolve_by_session
    ]

    strategies.each do |strategy|
      tenant = send(strategy)
      return tenant if tenant
    end

    nil
  end

  private

  def resolve_by_custom_header
    tenant_identifier = request.headers["X-Tenant-Identifier"]
    return nil unless tenant_identifier.present?

    Tenant.find_by(subdomain: tenant_identifier) ||
      Tenant.find_by(slug: tenant_identifier)
  end

  def resolve_by_subdomain
    return nil unless request.subdomain.present?

    Tenant.find_by(subdomain: request.subdomain)
  end

  def resolve_by_path_parameter
    # For routes like /t/:tenant_slug/dashboard
    tenant_slug = params[:tenant_slug]
    return nil unless tenant_slug.present?

    Tenant.find_by(slug: tenant_slug)
  end

  def resolve_by_user_preference
    return nil unless user_signed_in?

    tenant_id = current_user.preferred_tenant_id
    current_user.tenants.find_by(id: tenant_id) if tenant_id.present?
  end

  def resolve_by_session
    tenant_id = session[:selected_tenant_id]
    Tenant.find_by(id: tenant_id) if tenant_id.present?
  end
end

# Example 6: WebSocket Integration
module ApplicationCable
  # WebSocket connection with tenant context support
  # Establishes tenant context for real-time communication
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_tenant

    def connect
      self.current_user = find_verified_user
      self.current_tenant = find_tenant_for_user

      # Set tenant context for the connection
      PgMultitenantSchemas::Context.switch_to_tenant(current_tenant) if current_tenant
    end

    private

    def find_verified_user
      if (verified_user = User.find_by(id: cookies.signed[:user_id]))
        verified_user
      else
        reject_unauthorized_connection
      end
    end

    def find_tenant_for_user
      # Extract tenant from connection params or user preferences
      tenant_id = request.params[:tenant_id] || current_user.current_tenant_id
      current_user.tenants.find_by(id: tenant_id)
    end
  end
end

# Example WebSocket Channel with Tenant Context
class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to tenant-specific notifications
    if current_tenant
      stream_from "notifications_#{current_tenant.id}"
    else
      reject
    end
  end

  def receive(data)
    # All operations happen within tenant context
    PgMultitenantSchemas::Context.with_tenant(current_tenant) do
      case data["action"]
      when "mark_as_read"
        notification = Notification.find(data["notification_id"])
        notification.mark_as_read!
      when "create"
        Notification.create!(data["notification"])
      end
    end
  end
end
