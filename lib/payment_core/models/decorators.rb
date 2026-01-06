module PaymentCore
  module Models
    module Decorators

      autoload :Payable, 'payment_core/models/decorators/payable'
      autoload :Entry, 'payment_core/models/decorators/entry'
      autoload :PaymentMethod, 'payment_core/models/decorators/payment_method'
      autoload :PaymentMethodHolder, 'payment_core/models/decorators/payment_method_holder'
      autoload :PaymentMethodReference, 'payment_core/models/decorators/payment_method_reference'

    end
  end
end