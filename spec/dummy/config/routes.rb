Rails.application.routes.draw do
  get "/fiuu/return", to: "fiuu_returns#show"
  post "/fiuu/return", to: "fiuu_returns#show"
  mount PaymentCore::Engine => "/payment_core"
  # namespace :payment_gateway do
  #   mount ::PaymentCore::Grape::Base.draw(holder: false) => ""
  # end
end
