Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions" }

  resources :users, only: %i[index new create edit update]
  resource :settings, only: %i[edit update]

  get "menu", to: "menu#show", as: :menu

  resource :pos, only: :show, controller: "pos" do
    post "cart", action: :add_item
    patch "cart/:id", action: :update_item
    delete "cart/:id", action: :remove_item
    post "confirm", action: :confirm
  end

  resources :orders, only: %i[index show] do
    post :cancel, on: :member
    post :force_cancel, on: :member
    post :refund, on: :member
    resources :payments, only: %i[new create]
  end

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
