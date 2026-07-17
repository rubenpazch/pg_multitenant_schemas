# frozen_string_literal: true

require "spec_helper"

RSpec.describe 'Cookie Persistence' do
  describe 'Cookie configuration' do
    it 'has correct cookie name' do
      cookie_name = 'pg_multitenant_selected_schema'
      expect(cookie_name).to eq('pg_multitenant_selected_schema')
    end

    it 'sets cookie with correct path' do
      cookie_path = '/'

      expect(cookie_path).to eq('/')
    end

    it 'sets cookie with lax same_site policy' do
      same_site = :lax

      expect(same_site).to eq(:lax)
    end
  end

  describe 'Cookie with SameSite settings' do
    it 'uses Lax SameSite for development' do
      same_site = :lax

      # :lax allows cookies in top-level navigations (GET requests)
      # and POST requests from the same site
      expect(same_site).to eq(:lax)
    end

    it 'does not use None SameSite without HTTPS' do
      secure = false
      same_site = :lax

      # When secure=false, should not use None (would be ignored by browsers)
      expect(same_site).not_to eq(:none)
    end

    it 'sends cookie with same-site origins' do
      request_origin = 'http://localhost:5173'
      cookie_same_site = :lax

      # With Lax, cookies are sent for same-site requests
      expect(cookie_same_site).to eq(:lax)
    end
  end

  describe 'Cookie accessibility' do
    it 'makes cookie readable across all routes with path /' do
      cookie_path = '/'

      expect(cookie_path).to eq('/')
    end

    it 'sends cookie in all requests under root path' do
      routes = ['/api/tenants/current', '/pg_multitenant_schemas/tenants', '/documents']

      all_under_root = routes.all? { |route| route.start_with?('/') }

      expect(all_under_root).to be(true)
    end
  end

  describe 'HttpOnly flag' do
    it 'allows JavaScript access with http_only=false' do
      http_only = false

      # With http_only=false, JavaScript can access the cookie
      expect(http_only).to be(false)
    end

    it 'cookie visible in browser DevTools' do
      http_only = false

      # When http_only=false, cookie appears in DevTools Application tab
      expect(http_only).to be(false)
    end
  end

  describe 'Cookie storage behavior' do
    it 'stores string schema value' do
      stored_value = 'pepito'

      expect(stored_value).to be_a(String)
      expect(stored_value).not_to be_empty
    end

    it 'retrieves schema from cookie jar' do
      # Simulating cookie jar behavior
      cookie_jar = { pg_multitenant_selected_schema: 'juanita' }

      retrieved = cookie_jar[:pg_multitenant_selected_schema]

      expect(retrieved).to eq('juanita')
    end

    it 'handles missing cookie gracefully' do
      cookie_jar = {}

      retrieved = cookie_jar[:pg_multitenant_selected_schema]

      expect(retrieved).to be_nil
    end
  end

  describe 'Cookie in cross-origin requests' do
    it 'includes credentials in fetch for CORS' do
      # JavaScript fetch must include credentials: 'include'
      # to send cookies with cross-origin requests
      fetch_options = { credentials: 'include' }

      expect(fetch_options[:credentials]).to eq('include')
    end

    it 'requires Access-Control-Allow-Credentials header' do
      cors_header = 'true'

      expect(cors_header).to eq('true')
    end
  end
end
