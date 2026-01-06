module PaymentCore
  module Attributes
    module Entries
      module Metadata
        class AdjustmentMetadata < ::PaymentCore.config.payment_entry.metadata_base_class_constant
          attribute :adjustment_code, :string
        end
      end
    end
  end
end