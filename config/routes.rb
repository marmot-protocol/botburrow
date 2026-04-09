Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :setup, only: [ :new, :create ], controller: "setup"

  resources :bots do
    resources :commands, except: [ :show ] do
      patch :toggle_enabled, on: :member
    end
    resources :triggers, except: [ :show ] do
      patch :toggle_enabled, on: :member
    end
    resources :scheduled_actions, except: [ :show ] do
      patch :toggle_enabled, on: :member
    end
    resource :chat, only: [ :show, :create ], controller: "chat"
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
