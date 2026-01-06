module PaymentCore
  module Attributes
    module Entries
      module Metadata
        class WithdrawMetadata < ::PaymentCore.config.payment_entry.metadata_base_class_constant
          attribute :destination_account
          attribute :destination_provider
          attribute :destination_account_holder_name

        end
      end
    end
  end
end