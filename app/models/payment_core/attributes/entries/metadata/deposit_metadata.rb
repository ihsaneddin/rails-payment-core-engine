module PaymentCore
  module Attributes
    module Entries
      module Metadata
        class DepositMetadata < ::PaymentCore.config.payment_entry.metadata_base_class_constant
          attribute :deposit_code, :string
          attribute :source_system, :string
        end
      end
    end
  end
end