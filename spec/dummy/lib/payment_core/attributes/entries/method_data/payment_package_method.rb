module PaymentCore
  module Attributes
    module Entries
      module MethodData
        class PaymentPackageMethod < ::PaymentCore.config.payment_entry.method_data_base_class_constant

          self.method_type_value= "payment_package"

          attribute :note

        end
      end
    end
  end
end