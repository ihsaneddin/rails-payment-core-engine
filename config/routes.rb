PaymentCore::Engine.routes.draw do

  case PaymentCore.config.enabled_api
  when :grape
    mount PaymentCore::Grape::Base.draw => '/'
  when :action_controller
    #resources :products, only: [:index]
  end

end
