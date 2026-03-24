module PaymentCore
  module Grape
    module Resources
      autoload :Base, "payment_core/grape/resources/base"
      autoload :PaymentMethods, "payment_core/grape/resources/payment_methods"
      autoload :Entries, "payment_core/grape/resources/entries"
    end
  end
end
