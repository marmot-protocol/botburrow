Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :setup, only: [ :new, :create ], controller: "setup"

  resources :bots do
    resources :commands, except: [ :show ]
    member do
      post :start
      post :stop
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "bots#index"
end
