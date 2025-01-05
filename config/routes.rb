Rails.application.routes.draw do
  get "shopify_products/index"
  get "dashboard/index"
  root :to => 'home#index'
  get '/products', :to => 'products#index'
  # config/routes.rb
  get 'ebay/auth', to: 'ebay#auth'
  get 'ebay/callback', to: 'ebay#callback'

  mount ShopifyApp::Engine, at: '/'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  get 'dashboard', to: 'dashboard#index', as: :dashboard
  get 'shopify_products', to: 'shopify_products#index', as: :shopify_products
  get 'settings', to: 'settings#index', as: :settings
end
