module PaymentCore
  module Controllers
    module Concerns
      autoload :AuthenticateAdmin, "payment_core/controllers/concerns/authenticate_admin"
      autoload :CurrentHolder, "payment_core/controllers/concerns/current_holder"
      autoload :PaymentMethods, "payment_core/controllers/concerns/payment_methods"
    end
  end
end
