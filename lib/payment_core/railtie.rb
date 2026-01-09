require 'rails/railtie'

module PaymentCore
  class Railtie < ::Rails::Railtie

    initializer 'order_core.initialize' do
      ActiveSupport.on_load(:active_record) do
        include ::PaymentCore::Models::Decorators::Payable
        include ::PaymentCore::Models::Decorators::PaymentMethodReference
        include ::PaymentCore::Models::Decorators::PaymentMethodHolder
      end
    end

  end
end