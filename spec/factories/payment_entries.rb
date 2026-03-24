FactoryBot.define do
  factory :cash_charge_entry, class: "PaymentCore::Entries::Charge" do
    skip_create

    transient do
      holder { association :user }
      payment_method { association :cash_payment_method, holder: holder }
      item { association :product_item }
      order_name { "holder-entry" }
      currency { "MYR" }
    end

    initialize_with do
      order = create(:order, customer: holder, name: order_name, item: item)
      context = PaymentCore::Services::PaymentMethods::AvailabilityContext.new(
        currencies: [currency],
        payables: [order],
        user: holder
      )

      result = payment_method.processor(payer: holder, context: context).charge(
        payable: order,
        currency: currency,
        metadata: { payment_method_data: {} }
      )

      result.is_a?(PaymentCore::Entries::Wrapper) ? result.components.first : result
    end
  end
end
