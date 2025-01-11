Rails.application.routes.draw do
  get "shopify_products/index"
  get "dashboard/index"
  root :to => 'home#index'


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
  get 'orders', to: 'orders#index', as: :orders

  namespace :kuralis do
    resources :products
  end

  namespace :ebay do
    get 'auth', to: 'auth#auth'
    get 'callback', to: 'auth#callback'
    post 'notifications', to: 'notifications#create'
    get 'import_listings', to: 'auth#import_listings'
    resources :listings, only: [:index]
  end
end
