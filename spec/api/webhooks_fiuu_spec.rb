require "rails_helper"

RSpec.describe "PaymentCore Fiuu webhooks", type: :request do
  include Rack::Test::Methods

  def app
    PaymentCore::Grape::Base
  end

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

  def build_skey(tran_id:, order_id:, status:, domain:, amount:, currency:, paydate:, appcode:, secret_key:)
    key0 = Digest::MD5.hexdigest("#{tran_id}#{order_id}#{status}#{domain}#{amount}#{currency}")
    Digest::MD5.hexdigest("#{paydate}#{domain}#{key0}#{appcode}#{secret_key}")
  end

  it "captures webhook and updates entry state" do
    entry = processor.charge(payable: payable)

    method_data = entry.metadata.payment_method_data
    payload = method_data.gateway_request
    amount = payload[:amount] || payload["amount"]
    order_id = payload[:orderid] || payload["orderid"] || entry.number
    tran_id = "TX-123"
    status = "00"
    domain = "example-domain"
    currency = payload[:currency] || payload["currency"] || entry.currency
    paydate = "20250101120000"
    appcode = "APP-1"
    nbcb = "2"
    skey = build_skey(
      tran_id: tran_id,
      order_id: order_id,
      status: status,
      domain: domain,
      amount: amount,
      currency: currency,
      paydate: paydate,
      appcode: appcode,
      secret_key: payment_method.metadata_secret_key
    )

    post "/webhook/fiuu", {
      orderid: order_id,
      tranID: tran_id,
      status: status,
      amount: amount,
      currency: currency,
      paydate: paydate,
      appcode: appcode,
      skey: skey,
      domain: domain,
      nbcb: nbcb
    }

    expect([200, 201]).to include(last_response.status)

    entry.reload
    expect(entry).to be_succeeded
    expect(entry.payable_transaction_id).to eq(tran_id)
    payload = entry.metadata.payment_method_data.webhook_payload
    expect(payload[:orderid]).to eq(order_id)
    expect(payload[:tranID]).to eq(tran_id)
  end
end
