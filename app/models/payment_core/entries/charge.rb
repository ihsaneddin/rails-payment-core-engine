module PaymentCore
  module Entries
    class Charge < ::PaymentCore::Entry

      # setup core

      custom_attributes_definition :metadata, ::PaymentCore::Attributes::Entries::Metadata::ChargeMetadata, accessor: true

      self.direction = "in"

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