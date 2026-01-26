require "rails_helper"

RSpec.describe PaymentCore::Processors::Fiuu do

  before(:all) do
    Order; LineItem; User; Product; PaymentPackageProductValue
    Product::Item; Product::Service; Product::PaymentPackage
  end

  let(:payer) { User.create!(email: "user@example.com", name: "User") }
  let(:product_item) { Product::Item.create!(price: 100, name: "Test Item", sku: "item-1") }
  let(:payable) do
    order = Order.create!(customer: payer, name: "order-1", state: "waiting_payment")
    order.line_item_line_items.create!(item: product_item, quantity: 1, use_item_data: true)
    order.reload
  end
  let(:payment_method) do
    PaymentCore::PaymentMethods::Fiuu.create!(
      display_name: "Fiuu",
      active: true,
      always_available: true,
      metadata_merchant_id: "merchant-1",
      metadata_secret_key: "secret-1",
      metadata_verify_key: "verify-1"
    )
  end
  let(:context) do
    PaymentCore.config.payment_method.availability_context_class_constant.new(
      regions: ["ID"],
      currencies: ["RM"],
      use_cases: ["checkout"],
      payables: [payable]
    )
  end
  let(:processor) { payment_method.processor(payer: payer, context: context) }

  it "builds redirect payload and URL without calling the gateway" do
    entry = processor.charge(payable: payable)

    expect(entry).to be_persisted
    method_data = entry.metadata.payment_method_data
    expect(method_data.order_id).to eq(entry.number)
    expect(method_data.vcode).to be_present
    expect(method_data.gateway_request).to be_a(Hash)
    expect(method_data.gateway_request[:MerchantID]).to eq(payment_method.metadata_merchant_id)
    expect(method_data.redirect_url).to include("https://")
    expect(method_data.redirect_url).to include("/RMS/pay/merchant-1/")
  end

  it "raises when using direct flow" do
    payment_method.metadata.flow = "direct"
    payment_method.save!
    expect do
      processor.charge(
        payable: payable
      )
    end.to raise_error(PaymentCore::Errors::ProcessorActionNotAllowed)
  end
end
