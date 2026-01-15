module PaymentCore
  module Entries
    class Adjustment < ::PaymentCore::Entry

      # | Entry Type     | Allowed States                                                        | Notes                             |
      # | -------------- | --------------------------------------------------------------------- | --------------------------------- |
      # | **adjustment** | `succeeded`, `failed`                                                 | Usually a one-time admin op       |

      state_machine :state, initial: :succeeded do
      end

    end
  end
end