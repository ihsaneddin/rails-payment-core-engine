Rails.application.routes.draw do
  get "/fiuu/return", to: "fiuu_returns#show"
  mount PaymentCore::Engine => "/payment_core"
end
