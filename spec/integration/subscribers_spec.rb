require "rails_helper"

RSpec.describe "PaymentCore subscribers" do
  before(:all) do
    PaymentCore::Subscribers::EntrySubscriber
    PaymentCore::Subscribers::PaymentMethodSubscriber
  end

  it "completes order when entry succeeds via payable events" do
    user = create(:user, email: "user@example.com", name: "User")
    product_item = create(:product_item, price: 100, name: "Test Item", sku: "item-1")

    order = create(:order, customer: user, name: "order-1")
    create(:line_item, order: order, item: product_item, quantity: 1)
    order.reload

    payment_method = create(
      :cash_payment_method,
      display_name: "Cash",
      active: true,
      always_available: true,
      holder: nil
    )

    context = PaymentCore.config.payment_method.availability_context_class_constant.new(
      regions: ["MY"],
      currencies: ["MYR"],
      use_cases: ["checkout"],
      payables: [order]
    )

    processor = payment_method.processor(payer: user, context: context)
    entry = processor.charge(payable: order)

    expect(entry).to be_persisted
    order.reload
    expect(order.state).to eq("completed")
  end

  it "runs payment method holder events on payment method update" do
    user = create(:user, email: "user@example.com", name: "User")

    payment_method = create(
      :cash_payment_method,
      display_name: "Cash",
      active: true,
      always_available: true,
      holder: user
    )

    payment_method.update!(display_name: "Cash Updated")

    user.reload
    expect(user.name).to eq("payment_method_updated")
  end
end
