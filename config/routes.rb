Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :setup, only: [ :new, :create ], controller: "setup"

  resources :bots do
    resources :commands, except: [ :show ]
    resources :triggers, except: [ :show ]
    resources :scheduled_actions, except: [ :show ]
    resources :webhook_endpoints, except: [ :show ]
    resources :message_logs, only: [ :index ], path: "logs"
    member do
      post :start
      post :stop
      post :accept_invitation
      post :decline_invitation
    end
  end

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "up" => "rails/health#show", as: :rails_health_check

  root "bots#index"
end
