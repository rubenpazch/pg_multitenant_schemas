# frozen_string_literal: true

PgMultitenantSchemas::UI::Engine.routes.draw do
  root to: "tenants#index"

  resources :tenants, only: %i[index new create destroy] do
    member do
      post :migrate
      get  :migration_status
    end
    collection do
      post :migrate_all
      post :switch
    end
  end

  # Fallback for API-only apps where Rack::MethodOverride may be absent.
  # Keeps the same path used by RESTful DELETE forms, but accepts POST.
  post "/tenants/:id", to: "tenants#destroy"
end
