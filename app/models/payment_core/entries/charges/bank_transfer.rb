module PaymentCore
  module Entries
    module Charges
      class BankTransfer < ::PaymentCore::Entries::Charge
        self.entry_type = "charge"

        verification default: false do
          required_condition do
            payable&.payable_config.entry_requirements.try(:bank_transfer_charge_requires_verification)
          end
          max_attempt do
            payable&.payable_config.entry_requirements.try(:bank_transfer_charge_maximum_verification_attempt)
          end
        end

        requires_proof default: false do
          required_condition do
            verification_pending? && payable&.payable_config.entry_requirements.try(:bank_transfer_charge_requires_proof)
            #verification_config.required_condition && payable&.payable_config.entry_requirements.try(:bank_transfer_charge_requires_proof)
          end
        end

      end
    end
  end
end
