module PaymentCore
  module Entries
    class Wrapper < ::PaymentCore::Entry

      validates :payment_method, absence: true
      validate unless: :partial do
        if state_changed? && state == "succeeded"
          unless components.select(&:succeeded).sum(&:amount) >= amount
            errors.add(:amount, :invalid)
          end
        end
      end

      def may_success?
        partialed = partial ? true : components.sum(&:amount) >= amount
        !succeeded? && components.all?(&:succeeded?) && partialed
      end

      def success!
        self.succeeded_at= Time.current
        if partial
          self.amount= components.select(&:succeeded).sum(&:amount)
        end
        succeeded!
      end

      def charge?
        components.all?{|component| component.charge? }
      end

      def refund?
        components.all?{|component| component.refund? }
      end

    end
  end
end