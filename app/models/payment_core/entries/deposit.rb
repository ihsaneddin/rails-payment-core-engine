module PaymentCore
  module Entries
    class Deposit < ::PaymentCore::Entry

      # | Entry Type     | Allowed States                                                        | Notes                             |
      # | -------------- | --------------------------------------------------------------------- | --------------------------------- |
      # | **deposit**    | `succeeded`, `failed`, `pending`, `processing`                        | Often manually marked `succeeded` |

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

    end
  end
end