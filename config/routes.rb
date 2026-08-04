Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  resources :users, only: %i[index new create edit update]
  resource :settings, only: %i[edit update]

  get "menu", to: "menu#show", as: :menu

  resources :categories, except: :show
  resources :products do
    resources :product_variants, except: %i[index show]
    resources :product_addon_groups, except: %i[index show] do
      resources :product_addons, except: %i[index show]
    end
  end

  root to: "home#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
