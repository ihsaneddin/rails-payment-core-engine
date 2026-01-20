module PaymentCore
  module Grape
    module Presenters
      autoload :Base, "payment_core/grape/presenters/base"
      autoload :Entry, "payment_core/grape/presenters/entry"
      autoload :PaymentIntent, "payment_core/grape/presenters/payment_intent"
      autoload :PaymentMethod, "payment_core/grape/presenters/payment_method"
      autoload :PaymentMethodReference, "payment_core/grape/presenters/payment_method_reference"
    end
  end
end
