module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module IntentDriven

          def self.included base
            invalid_class?(base)
            base.extend ClassMethods
          end

          def self.default_options
            {
              #....
            }
          end

          module ClassMethods

            def intent_driven(**opts, &block)

              validates :payment_intent, presence: true

              validate do
                if payment_intent
                  errors.add(:payment_intent, :invalid) unless payment_intent.valid_to_be_used?
                end
              end

              after_save do
                if after_state_succeeded?
                  payment_intent.confirmed!
                end
              end

            end

          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object

        end
      end
    end
  end
end
