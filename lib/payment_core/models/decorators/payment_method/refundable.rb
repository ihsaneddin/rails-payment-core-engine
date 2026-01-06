module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module Refundable


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

            def refundable(**opts, &block)
              allows_entry_type('refund')
            end

          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object

        end
      end
    end
  end
end
