require 'rails/railtie'

module PaymentCore
  class Railtie < ::Rails::Railtie

    initializer 'order_core.initialize' do
      ActiveSupport.on_load(:active_record) do
        include ::PaymentCore.decorators.payable
        include ::PaymentCore.decorators.payment_method_reference
        include ::PaymentCore.decorators.payment_method_holder
      end
    end

  end
end