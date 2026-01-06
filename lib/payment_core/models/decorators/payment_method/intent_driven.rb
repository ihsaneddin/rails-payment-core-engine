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

            end

          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object

        end
      end
    end
  end
end
