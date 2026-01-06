module PaymentCore
  module Attributes
    module Entries
      module Metadata
        class RefundMetadata < ::PaymentCore.config.payment_entry.metadata_base_class_constant
          attribute :refund_code, :string
        end
      end
    end
  end
end