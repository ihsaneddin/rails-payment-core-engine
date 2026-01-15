module PaymentCore
  module Errors

    class ApiAuthenticationError < StandardError

    end

    class ApiAuthorizationError < StandardError

    end

    class UnknownProcessorError < StandardError; end
    class UnknownProcessorActionError < StandardError; end
    class InvalidPaymentMethodOnProcessor < StandardError; end

  end
end