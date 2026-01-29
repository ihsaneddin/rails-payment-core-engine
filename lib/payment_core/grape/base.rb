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

      def self.draw(&block)
        klass = duplicate(self)
        klass.class_exec(&block) if block_given?
        klass.mount ::PaymentCore::Grape::Holder::Base.draw
        klass.mount ::PaymentCore::Grape::Webhooks.draw
        klass
      end


    end
  end
end
