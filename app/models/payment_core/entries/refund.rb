module PaymentCore
  module Entries
    class Refund < ::PaymentCore::Entry

      custom_attributes_definition :metadata, ::PaymentCore::Attributes::Entries::Metadata::RefundMetadata, accessor: true

      self.direction = "out"

      # | Entry Type     | Allowed States                                                        | Notes                             |
      # | -------------- | --------------------------------------------------------------------- | --------------------------------- |
      # | **refund**     | `pending`, `processing`, `succeeded`, `failed`                        | No `expired`, rarely `canceled`   |

      state_machine :state, initial: :pending do
        event :process do
          transition [:pending, :failed] => :processing
        end
        event :success do
          transition [:pending, :failed, :processing] => :succeeded
        end
        event :failure do
          transition [:pending, :processing] => :failed
        end
      end

      attr_accessor :use_payable_data

      with_options if: proc {|record| record.use_payable_data && record.payable } do
        before_validation do
          self.amount = payable.payable_total_amount
          self.payment_method = payable.try(:payment_method)
          if self.payment_method
            self.payment_method_amount = payable.payable_payment_method_total_amount(payment_method)
          end
        end
      end

    end
  end
end