module PaymentCore
  module Entries
    class Charge < ::PaymentCore::Entry

      define_metadata_class(::PaymentCore::Attributes::Entries::Metadata::ChargeMetadata)

      self.direction = "in"

      # | Entry Type     | Allowed States                                                        | Notes                             |
      # | -------------- | --------------------------------------------------------------------- | --------------------------------- |
      # | **charge**     | `pending`, `processing`, `succeeded`, `failed`, `canceled`, `expired` | Most common stateful process      |

      state_machine :state, initial: :pending do
        event :process do
          transition [:pending, :failed] => :processing
        end
        event :success do
          transition [:pending, :failed, :processing] => :succeeded
        end
        event :cancel do
          transition [:pending, :failed, :processing] => :canceled
        end
        event :expiry do
          transition [:pending, :processing] => :expired
        end
        event :failure do
          transition [:pending, :processing] => :failed
        end
      end

      payable do
        quantity 1
        total_item_amount :amount
        total_amount :amount
        paid_amount do
          payable_entries.with_entry_types("refund").succeeded
          .sum(:amount)
        end
        currency :currency
        payment_method_item_amount do |payment_method|
          payment_method_amount
        end
      end

    end
  end
end