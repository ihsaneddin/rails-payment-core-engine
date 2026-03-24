module PaymentCore
  class ApplicationController < ActionController::Base
    use_plugins_controllers(PaymentCore::Configuration::Api)
  end
end
