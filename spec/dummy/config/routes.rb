Rails.application.routes.draw do
  mount PaymentCore::Engine => "/payment_core"
end
