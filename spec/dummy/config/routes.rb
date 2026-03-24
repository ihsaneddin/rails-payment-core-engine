Rails.application.routes.draw do
  get "/fiuu/return", to: "fiuu_returns#show"
  post "/fiuu/return", to: "fiuu_returns#show"

  scope path: "admin", as: :admin do
    resources :payment_methods, controller: :payment_methods
    post "payment_methods/:method_type/:processor_action",
         to: "payment_methods#collective_processor_action",
         as: :payment_method_collective_processor_action
    post "payment_method/:id/:processor_action",
         to: "payment_methods#member_processor_action",
         as: :payment_method_processor_action

    get "entries", to: "entries#index", as: :entries
    get "entry/:id", to: "entries#show", as: :entry
  end

  mount PaymentCore::Engine => "/payment_core"
  # namespace :payment_gateway do
  #   mount ::PaymentCore::Grape::Base.draw(holder: false) => ""
  # end
end
