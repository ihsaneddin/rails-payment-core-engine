require "rails_helper"

RSpec.describe "PaymentCore Fiuu webhooks", type: :request do
  include Rack::Test::Methods

  def app
    PaymentCore::Grape::Base.draw
  end

  before(:all) do
    Order; LineItem; User; Product; PaymentPackageProductValue
    Product::Item; Product::Service; Product::PaymentPackage
    PaymentCore::Attributes::Entries::MethodData::FiuuMethod
  end

  let(:payer) { create(:user, email: "user@example.com", name: "User") }
  let(:product_item) { create(:product_item, price: 100, name: "Test Item", sku: "item-1") }
  let(:payable) do
    order = create(:order, customer: payer, name: "order-1", state: "cart")
    create(:line_item, order: order, item: product_item, quantity: 1)
    order
  end
  let(:payment_method) do
    create(
      :fiuu_payment_method,
      display_name: "Fiuu",
      active: true,
      always_available: true,
      holder: payer,
      metadata_merchant_id: "merchant-1",
      metadata_secret_key: "secret-1",
      metadata_verify_key: "verify-1"
    )
  end
  let(:context) { build(:payment_method_availability_context, payables: [payable]) }
  let(:processor) { payment_method.processor(payer: payer, context: context) }

  def json_body
    JSON.parse(last_response.body)
  end

  it "captures webhook and updates entry state" do
    payable.update!(state: "waiting_payment")
    allow(payment_method).to receive(:require_intent?).and_return(false)
    allow_any_instance_of(PaymentCore::Gateways::Fiuu)
      .to receive(:build_redirect_payload) do |_gateway, payment_method_data:, amount:, currency:, **_opts|
        [
          {
            amount: amount,
            currency: currency,
            orderid: payment_method_data.order_id
          },
          {
            order_id: payment_method_data.order_id,
            vcode: "stub-vcode"
          }
        ]
      end
    allow_any_instance_of(PaymentCore::Gateways::Fiuu)
      .to receive(:redirect_path)
      .and_return("/RMS/pay/merchant-1/")
    allow_any_instance_of(PaymentCore::Gateways::Fiuu)
      .to receive(:build_url)
      .and_return("https://pay.fiuu.test/RMS/pay/merchant-1/")

    entry = processor.charge(payable: payable)
    expect(entry).to be_persisted

    order_id = entry.number
    tran_id = "TX-123"
    status = "00"
    webhook_payload = {
      orderid: order_id,
      tranID: tran_id,
      status: status,
      amount: entry.payment_method_amount || entry.amount,
      currency: entry.currency
    }

    allow(PaymentCore::Gateways::Fiuu).to receive(:config_entry_resolver).and_return(entry)
    allow_any_instance_of(PaymentCore::Gateways::Fiuu)
      .to receive(:normalize_webhook_payload)
      .and_return(webhook_payload)

    now = Time.current
    post "/webhook/fiuu", {
      orderid: order_id,
      tranID: tran_id
    }

    expect([200, 201]).to include(last_response.status)

    entry.reload
    expect(entry).to be_succeeded
    expect(entry.payable_transaction_id).to eq(tran_id)
    payload = entry.metadata.payment_method_data.webhook_payload
    expect(entry.metadata.payment_method_data.last_webhook_attempt_at).to be_within(5.seconds).of(now)
    expect(payload[:orderid]).to eq(order_id)
    expect(payload[:tranID]).to eq(tran_id)
  end
end
