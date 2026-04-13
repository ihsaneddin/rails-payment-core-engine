module PaymentCore
  module Entries
    class Withdraw < ::PaymentCore::Entry

      # | Entry Type     | Allowed States                                                        | Notes                             |
      # | -------------- | --------------------------------------------------------------------- | --------------------------------- |
      # | **withdraw**   | `pending`, `processing`, `succeeded`, `failed`, `canceled`            | Typically async to a bank         |

      state_machine :state, initial: :pending do
        event :process do
          transition [:pending, :failed] => :processing
        end
        event :cancel do
          transition [:pending, :processing, :failed] => :canceled
        end
        event :success do
          transition [:failed, :processing] => :succeeded
        end
        event :failure do
          transition [:processing] => :failed
        end
      end

    end
  end
end