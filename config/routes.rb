Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Error routes (Phase 13)
  match "/404", to: "errors#not_found", via: :all
  match "/422", to: "errors#unprocessable", via: :all
  match "/500", to: "errors#internal_error", via: :all

  # Admin impersonation (Phase 13)
  post "impersonate/:id", to: "admin#impersonate", as: :impersonate
  post "stop_impersonating", to: "admin#stop_impersonating", as: :stop_impersonating

  # Dev error routes (development only, Phase 13)
  if Rails.env.development?
    get "dev/errors/404", to: "dev_errors#not_found"
    get "dev/errors/500", to: "dev_errors#internal_error"
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Team-scoped routes (Phase 6)
  scope "/teams/:team_id", constraints: { team_id: /\d+/ } do
    resources :posts
    
    namespace :settings, module: "teams/settings" do
      resource :general, only: [:show, :update], controller: "general"
      resources :memberships, only: [:index, :update, :destroy]
    end
    get "settings", to: redirect { |params, _| "/teams/#{params[:team_id]}/settings/general" }
  end

  # Defines the root path route ("/")
  root "home#index"
  
  # Articles (Phase 11)
  resources :articles, path: "a", only: [:index, :show]
  
  # UI Test page (Phase 4 verification)
  get "ui_test" => "ui_test#index"
  
  # Authentication (Phase 5)
  resource :session, only: [:new, :create, :destroy] do
    scope module: :sessions do
      resource :magic_link, only: [:show, :create]
    end
  end

  # Profile & Email Change (Phase 7)
  resource :profile, only: [:show, :update]

  namespace :users do
    resources :email_addresses, only: [:new, :create] do
      resource :confirmation, only: [:show, :create], module: :email_addresses
    end
  end

  # Redirect old paths
  get "/users/sign_in", to: redirect("/session/new")
  get "/users/sign_up", to: redirect("/session/new")
end
