module PaymentCore
  module PaymentMethods
    class BankTransfer < ::PaymentCore::PaymentMethod

      self.method_type= "bank_transfer"

      bank_transferable
      intent_driven

      entry_method_data_defaults do
        {
          recipient_account_number: bank_account_number,
          recipient_account_name: bank_account_name,
          recipient_bank: bank_name,
          recipient_bank_code: bank_code,
          currency: default_currency
        }.compact
      end

      allows_entry_type "charge_bank_transfer"

    end
  end
end
