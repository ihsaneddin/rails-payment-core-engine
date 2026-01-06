module PaymentCore
  module Attributes
    module Entries
      module MethodData
        class CashMethod < ::PaymentCore.config.payment_entry.method_data_base_class_constant

          self.method_type_value= "cash"

          attribute :received_by, :string
          attribute :location, :string
          attribute :note
          attribute :paid_amount
          attribute :currency

        end
      end
    end
  end
end