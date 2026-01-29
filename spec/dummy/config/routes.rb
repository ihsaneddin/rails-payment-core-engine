Rails.application.routes.draw do
  get "/fiuu/return", to: "fiuu_returns#show"
  post "/fiuu/return", to: "fiuu_returns#show"
  mount PaymentCore::Engine => "/payment_core"
  namespace :payment_gateway do
    api = ::PaymentCore::Grape::Webhooks.draw do
      use_plugins_grape(PaymentCore.config.grape_api)
    end
    mount api => ""
  end
end
