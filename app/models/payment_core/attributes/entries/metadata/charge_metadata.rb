module PaymentCore
  module Attributes
    module Entries
      module Metadata
        class ChargeMetadata < ::PaymentCore.config.payment_entry.metadata_base_class_constant
          attribute :charge_code, :string
        end
      end
    end
  end
end