module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module Provisioned

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

            def provisioned(**opts, &block)
              include PaymentCore::Models::Decorators::PaymentMethod::IntentDriven
            end

          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object

        end
      end
    end
  end
end
