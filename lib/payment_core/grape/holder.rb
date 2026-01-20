module PaymentCore
  module Grape
    module Holder

      autoload :Base, "payment_core/grape/holder/base"
      autoload :Entries, "payment_core/grape/holder/entries"
      autoload :PaymentMethods, "payment_core/grape/holder/payment_methods"

    end
  end
end
