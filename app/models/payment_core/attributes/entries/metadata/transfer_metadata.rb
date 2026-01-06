module PaymentCore
  module Attributes
    module Entries
      module Metadata
        class TransferMetadata < ::PaymentCore.config.payment_entry.metadata_base_class_constant
          attribute :from_account_holder_name, :string
          attribute :from_account, :string
          attribute :from_account_provider, :string
          attribute :to_account_holder_name, :string
          attribute :to_account_label, :string
          attribute :to_account_provider, :string
        end
      end
    end
  end
end