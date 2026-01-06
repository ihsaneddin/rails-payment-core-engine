module PaymentCore
  module Models
    module Decorators
      module PaymentMethod

        # autoload :AutomaticCapture, "payment_core/models/decorators/payment_method/automatic_capture"
        # autoload :Cancelable, "payment_core/models/decorators/payment_method/cancelable"
        # autoload :Expirable, "payment_core/models/decorators/payment_method/expirable"
        # autoload :Holder, "payment_core/models/decorators/payment_method/holder"
        # autoload :IntentDriven, "payment_core/models/decorators/payment_method/intent_driven"
        # autoload :ManualCapture, "payment_core/models/decorators/payment_method/manual_capture"
        # autoload :Object, "payment_core/models/decorators/payment_method/object"
        # autoload :Provisioned, "payment_core/models/decorators/payment_method/provisioned"
        # autoload :Reference, "payment_core/models/decorators/payment_method/reference"
        # autoload :Refundable, "payment_core/models/decorators/payment_method/refundable"
        # autoload :UseReference, "payment_core/models/decorators/payment_method/use_reference"
        # autoload :Reusable, "payment_core/models/decorators/payment_method/reusable"
        # autoload :Withdrawable, "payment_core/models/decorators/payment_method/withdrawable"
        #
        require "payment_core/models/decorators/payment_method/object"
        require "payment_core/models/decorators/payment_method/automatic_capture"
        require "payment_core/models/decorators/payment_method/cancelable"
        require "payment_core/models/decorators/payment_method/expirable"
        require "payment_core/models/decorators/payment_method/intent_driven"
        require "payment_core/models/decorators/payment_method/manual_capture"
        require "payment_core/models/decorators/payment_method/provisioned"
        require "payment_core/models/decorators/payment_method/refundable"
        require "payment_core/models/decorators/payment_method/uses_reference"
        require "payment_core/models/decorators/payment_method/reusable"
        require "payment_core/models/decorators/payment_method/withdrawable"

        def self.automatic_capture
          AutomaticCapture
        end

        def self.cancelable
          Cancelable
        end

        def self.expirable
          Expirable
        end

        def self.intent_driven
          IntentDriven
        end

        def self.manual_capture
          ManualCapture
        end

        def self.object
          Object
        end

        def self.provisioned
          Provisioned
        end

        def self.refundable
          Refundable
        end

        def self.uses_reference
          UsesReference
        end

        def self.reusable
          Reusable
        end

        def self.withdrawable
          Withdrawable
        end

      end
    end
  end
end
