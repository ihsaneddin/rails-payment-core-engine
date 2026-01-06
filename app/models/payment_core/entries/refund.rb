module PaymentCore
  module Entries
    class Refund < ::PaymentCore::Entry

      custom_attributes_definition :metadata, ::PaymentCore::Attributes::Entries::Metadata::RefundMetadata, accessor: true

      self.direction = "out"

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

      # va

    end
  end
end