module PaymentCore
  module Models
    module Decorators
      module PaymentMethod

        extend ActiveSupport::Autoload

        autoload :Object, "payment_core/models/decorators/payment_method/object"
        autoload :AutomaticCapture, "payment_core/models/decorators/payment_method/automatic_capture"
        autoload :Cancelable, "payment_core/models/decorators/payment_method/cancelable"
        autoload :Expirable, "payment_core/models/decorators/payment_method/expirable"
        autoload :ExternalReference, "payment_core/models/decorators/payment_method/external_reference"
        autoload :IntentDriven, "payment_core/models/decorators/payment_method/intent_driven"
        autoload :ManualCapture, "payment_core/models/decorators/payment_method/manual_capture"
        autoload :Provisioned, "payment_core/models/decorators/payment_method/provisioned"
        autoload :Refundable, "payment_core/models/decorators/payment_method/refundable"
        autoload :UsesReference, "payment_core/models/decorators/payment_method/uses_reference"
        autoload :Reusable, "payment_core/models/decorators/payment_method/reusable"
        autoload :Withdrawable, "payment_core/models/decorators/payment_method/withdrawable"
        autoload :BankTransferable, "payment_core/models/decorators/payment_method/withdrawable"

        #
        # require "payment_core/models/decorators/payment_method/object"
        # require "payment_core/models/decorators/payment_method/automatic_capture"
        # require "payment_core/models/decorators/payment_method/cancelable"
        # require "payment_core/models/decorators/payment_method/expirable"
        # require "payment_core/models/decorators/payment_method/intent_driven"
        # require "payment_core/models/decorators/payment_method/manual_capture"
        # require "payment_core/models/decorators/payment_method/provisioned"
        # require "payment_core/models/decorators/payment_method/refundable"
        # require "payment_core/models/decorators/payment_method/uses_reference"
        # require "payment_core/models/decorators/payment_method/reusable"
        # require "payment_core/models/decorators/payment_method/withdrawable"

      end
    end
  end
end
