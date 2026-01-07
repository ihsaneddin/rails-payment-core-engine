module PaymentCore
  module Models
    module Decorators
      module Entry
        module Charge

          extend ActiveSupport::Concern

          included do

            self.direction = "charge"

            def self.inherited(subclass)
              super(subclass)
              subclass.define_charge_entries_relation_to_payable_classes
            end

            def define_charge_entries_relation_to_payable_classes
              ::PaymentCore.decorators.payable.payable_classes.each do |payable_class|
                payable_class.define_payable_entry_relation(self)
              end
            end

            define_charge_entries_relation_to_payable_classes

          end

        end
      end
    end
  end
end