module PaymentCore
  module Services
    module PaymentMethods

      autoload :AvailabilityContext, "payment_core/services/payment_methods/availability_context"
      autoload :AvailabilityMatcher, "payment_core/services/payment_methods/availability_matcher"
      autoload :ChargeAllocator, "payment_core/services/payment_methods/charge_allocator"

    end
  end
end