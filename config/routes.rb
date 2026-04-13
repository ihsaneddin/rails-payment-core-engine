PaymentCore::Engine.routes.draw do

  case PaymentCore.config.enabled_api
  when :grape
    mount PaymentCore::Grape::Base.draw => '/'
  when :action_controller
    scope module: :holder, path: "holder/:holder_type/:holder_id", as: :holder do
      get "payment_methods", to: "payment_methods#index", as: :payment_methods
      get "payment_methods/available", to: "payment_methods#available", as: :available_payment_methods
      get "payment_method/:id", to: "payment_methods#show", as: :payment_method
      post "payment_methods/:method_type/:processor_action", to: "payment_methods#collective_processor_action", as: :payment_method_collective_processor_action
      post "payment_method/:id/:processor_action", to: "payment_methods#member_processor_action", as: :payment_method_processor_action

      get "entries", to: "entries#index", as: :entries
      get "entry/:id", to: "entries#show", as: :entry
    end

    scope module: :admin, path: "admin", as: :admin do
      resources :payment_methods, controller: :payment_methods
      post "payment_methods/:method_type/:processor_action", to: "payment_methods#collective_processor_action", as: :payment_method_collective_processor_action
      post "payment_method/:id/:processor_action", to: "payment_methods#member_processor_action", as: :payment_method_processor_action

      get "entries", to: "entries#index", as: :entries
      get "entry/:id", to: "entries#show", as: :entry
    end
  end

end
