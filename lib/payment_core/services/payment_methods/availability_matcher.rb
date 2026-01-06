module PaymentCore
  module Services
    module PaymentMethods
      class AvailabilityMatcher

        attr_reader :payment_method, :context, :payables, :holder

        def initialize(payment_method: nil, context: nil, holder: nil, payables: [])
          @context = context
          @payment_method = payment_method
          @holder = holder || payment_method&.holder
          @payables = payables || []
          @payables = @payables.concat(context&.payables || [])
        end

        def available?
          return true if payment_method.always_available
          payment_method_is_available? && payment_method_is_available_by_holder? && payment_method_is_available_by_payables?
        end

        def payment_method_is_available?
          payment_method.should_payment_method_be_available?(context)
        end

        def payment_method_is_available_by_holder?
          !holder || holder.should_payment_method_be_available?(payment_method, context)
        end

        def payment_method_is_available_by_payables?
          payables.blank? || payables.all?{|payable| payable.should_payment_method_be_available?(payment_method, context) }
        end

      end
    end
  end
end