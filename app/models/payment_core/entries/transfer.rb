module PaymentCore
  module Entries
    class Transfer < ::PaymentCore::Entry

      # | Entry Type     | Allowed States                                                        | Notes                             |
      # | -------------- | --------------------------------------------------------------------- | --------------------------------- |
      # | **transfer**   | `succeeded`, `failed`, `processing`                                   | Can be instantaneous or queued    |

      state_machine :state, initial: :processing do
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