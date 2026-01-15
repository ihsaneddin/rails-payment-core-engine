module PaymentCore
  module Entries
    class Wrapper < ::PaymentCore::Entry

      # | Entry Type     | Allowed States                                                        | Notes                             |
      # | -------------- | --------------------------------------------------------------------- | --------------------------------- |
      # | **wrapper**    | `pending`, `succeeded`, `failed`                                      | for wrapper                       |

      state_machine :state, initial: :pending do
        event :process do
          transition pending: :processing
        end
        event :success do
          transition [:pending, :failed, :processing] => :succeeded
        end

        event :failure do
          transition [:pending, :processing] => :failed
        end

      end
      before_state_transition :state, to: :succeeded do
        set_wrapper_amount
        components_cover_amount?
      end

      validates :payment_method, absence: true

      def charge?
        components.all?{|component| component.charge? }
      end

      def refund?
        components.all?{|component| component.refund? }
      end

      private

      def set_wrapper_amount
        if partial
          self.amount = components.select(&:succeeded?).sum(&:amount)
        end
      end

      def components_cover_amount?
        covered = components.select(&:succeeded?).sum(&:amount)
        errors.add(:amount, :components_insufficient) if covered < amount
        errors.blank?
      end

    end
  end
end
