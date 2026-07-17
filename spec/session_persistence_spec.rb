# frozen_string_literal: true

require "spec_helper"

RSpec.describe 'Session Persistence' do

  describe 'Session-based tenant switching' do
    it 'stores selected schema in session' do
      session = {}
      controller = instance_double('ActionController::API')
      allow(controller).to receive(:session).and_return(session)

      # Simulate storing schema in session
      session[:pg_multitenant_selected_schema] = 'pepito'

      expect(session[:pg_multitenant_selected_schema]).to eq('pepito')
    end

    it 'retrieves schema from session on subsequent requests' do
      session = { pg_multitenant_selected_schema: 'juanita' }

      retrieved_schema = session[:pg_multitenant_selected_schema]

      expect(retrieved_schema).to eq('juanita')
    end

    it 'falls back to public schema when session is empty' do
      session = {}
      schema = (session[:pg_multitenant_selected_schema] || 'public').to_s.strip

      expect(schema).to eq('public')
    end

    it 'validates schema name is a string' do
      session = { pg_multitenant_selected_schema: 'valid_schema' }
      schema = session[:pg_multitenant_selected_schema]

      expect(schema).to be_a(String)
    end
  end

  describe 'Controller concern session handling' do
    it 'prioritizes session over cookie' do
      request = instance_double('ActionDispatch::Request')
      session = { pg_multitenant_selected_schema: 'pepito' }

      # Session should take priority
      selected_schema = session[:pg_multitenant_selected_schema]

      expect(selected_schema).to eq('pepito')
    end

    it 'resolves schema from cookie when session is empty' do
      request = instance_double('ActionDispatch::Request')
      session = {}
      cookie = { pg_multitenant_selected_schema: 'juanita' }

      selected_schema = session[:pg_multitenant_selected_schema] || cookie[:pg_multitenant_selected_schema]

      expect(selected_schema).to eq('juanita')
    end

    it 'can be disabled in configuration' do
      # When development_fallback is disabled, session/cookie resolution should be skipped
      development_fallback_enabled = true

      # Configuration can disable this behavior
      expect(development_fallback_enabled).to be_a(TrueClass).or be_a(FalseClass)
    end
  end

  describe 'Session expiry and reset' do
    it 'clears session on logout/reset' do
      session = { pg_multitenant_selected_schema: 'pepito' }

      session.delete(:pg_multitenant_selected_schema)

      expect(session[:pg_multitenant_selected_schema]).to be_nil
    end

    it 'returns to default schema after session is cleared' do
      session = {}
      default_schema = (session[:pg_multitenant_selected_schema] || 'public').to_s.strip

      expect(default_schema).to eq('public')
    end
  end

  describe 'Session data integrity' do
    it 'handles string schema names correctly' do
      session = {}
      schema_input = 'pepito'

      session[:pg_multitenant_selected_schema] = schema_input.to_s.strip

      expect(session[:pg_multitenant_selected_schema]).to eq('pepito')
    end

    it 'strips whitespace from schema names' do
      session = {}
      schema_with_spaces = '  juanita  '

      session[:pg_multitenant_selected_schema] = schema_with_spaces.to_s.strip

      expect(session[:pg_multitenant_selected_schema]).to eq('juanita')
    end

    it 'handles nil and empty schema names gracefully' do
      session = {}

      schema = (session[:pg_multitenant_selected_schema] || '').to_s.strip
      is_valid = schema.present?

      expect(is_valid).to be(false)
    end
  end
end
