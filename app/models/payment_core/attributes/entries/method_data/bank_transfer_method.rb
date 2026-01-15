module PaymentCore
  module Attributes
    module Entries
      module MethodData
        class BankTransferMethod < ::PaymentCore.config.payment_entry.method_data_base_class_constant

          self.method_type_value= "bank_transfer"

          attribute :recipient_account_number, :string
          attribute :recipient_account_name, :string
          attribute :recipient_bank, :string
          attribute :recipient_bank_code, :string
          attribute :sender_account, :string
          attribute :sender_bank, :string
          attribute :sender_bank_code, :string
          attribute :paid_amount, type: :decimal
          attribute :currency
          attribute :transfer_reference
          attribute :transfered_at, type: :datetime

        end
      end
    end
  end
end
