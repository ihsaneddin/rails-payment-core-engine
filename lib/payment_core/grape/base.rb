module PaymentCore
  module Grape
    autoload :Holder, "payment_core/grape/holder"
    autoload :Helpers, "payment_core/grape/helpers"
    autoload :Presenters, "payment_core/grape/presenters"
    autoload :Webhooks, "payment_core/grape/webhooks"

    class Base < ::Grape::API

      use_plugins_grape(PaymentCore.config.grape_api)

      format :json

      prefix api_config.prefix if api_config.prefix

      include PaymentCore::Grape::Helpers
      include PaymentCore::Grape::Helpers::Authenticate
      include PaymentCore::Grape::Helpers::Authorize

      resource_context("payment_core")

      mount ::PaymentCore::Grape::Holder::Base
      mount ::PaymentCore::Grape::Webhooks.draw


    end
  end
end
