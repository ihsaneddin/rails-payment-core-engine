module PaymentCore
  module Models
    module Decorators
      module Entry

        autoload :Object, "payment_core/models/decorators/entry/object"
        autoload :RequiresProof, "payment_core/models/decorators/entry/requires_proof"
        autoload :RequiresVerification, "payment_core/models/decorators/entry/requires_verification"

      end
    end
  end
end
