require 'sidekiq/web'

Rails.application.routes.draw do
  # Commenting out devise routes for now
  # devise_for :users
  
  # Protect Sidekiq web UI with basic auth
  if Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(username),
        ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_USERNAME"])
      ) &
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(password),
        ::Digest::SHA256.hexdigest(ENV["SIDEKIQ_PASSWORD"])
      )
    end
  end

  mount Sidekiq::Web => '/sidekiq'
  
  get "shopify_products/index"
  get "dashboard/index"
  root :to => 'home#index'


  mount ShopifyApp::Engine, at: '/'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get 'dashboard', to: 'dashboard#index', as: :dashboard
  get 'shopify_products', to: 'shopify_products#index', as: :shopify_products   
  get 'settings', to: 'settings#index', as: :settings
  get 'orders', to: 'orders#index', as: :orders

  namespace :kuralis do
    resources :products
  end

  namespace :ebay do
    get 'auth', to: 'auth#auth'
    get 'callback', to: 'auth#callback'
    post 'notifications', to: 'notifications#create'
    resources :listings, only: [:index] do
      collection do
        resources :synchronizations, only: [:create]
      end
    end
  end
end
