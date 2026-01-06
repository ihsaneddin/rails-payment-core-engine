module PaymentCore
  module Grape
    class Base < ::Grape::API

      use_plugins_grape(PaymentCore.config.grape_api)

      format :json

      prefix api_config.prefix if api_config.prefix

      include PaymentCore::Grape::Helpers
      include PaymentCore::Grape::Helpers::Authenticate
      include PaymentCore::Grape::Helpers::Authorize

      resource_context("payment_core")

      mount ::PaymentCore::Grape::Holder::Base


    end
  end
end
