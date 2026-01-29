require "rails_helper"

RSpec.describe "PaymentCore holder processor actions", type: :request do
  include Rack::Test::Methods

  def app
    PaymentCore::Grape::Base.draw
  end

  before(:all) do
    Order; LineItem; User; Product; PaymentPackageProductValue
    Product::Item; Product::Service; Product::PaymentPackage
  end

  let(:user) { User.create!(email: "user@example.com", name: "User") }
  let(:holder_type) { user.class.payment_method_holder_api.type }

  let(:product_item) { Product::Item.create!(price: 10, name: "Product Item", sku: "item-1") }
  let(:product_service) { Product::Service.create!(price: 15, name: "Product Service", sku: "svc-1") }
  let(:product_top_up_service_package) do
    Product::PaymentPackage.create!(
      price: 20,
      name: "Service Package Top Up",
      sku: "pkg-1",
      amount_per_quantity: 100,
      allow_purchase_on_any_item: false,
      disallow_purchase_on_item_ids: [product_item.id],
      will_be_expired: false,
      currency: "Service Package",
      custom_value: true,
      product_values_attributes: [
        { product_id: product_service.id, value: 10 }
      ]
    )
  end
  let(:product_top_up_service_package_small_a) do
    Product::PaymentPackage.create!(
      price: 20,
      name: "Service Package Split A",
      sku: "pkg-split-a",
      amount_per_quantity: 50,
      allow_purchase_on_any_item: false,
      disallow_purchase_on_item_ids: [product_item.id],
      will_be_expired: false,
      currency: "Service Package A",
      custom_value: true,
      product_values_attributes: [
        { product_id: product_service.id, value: 10 }
      ]
    )
  end
  let(:product_top_up_service_package_small_b) do
    Product::PaymentPackage.create!(
      price: 20,
      name: "Service Package Split B",
      sku: "pkg-split-b",
      amount_per_quantity: 50,
      allow_purchase_on_any_item: false,
      disallow_purchase_on_item_ids: [product_item.id],
      will_be_expired: false,
      currency: "Service Package B",
      custom_value: true,
      product_values_attributes: [
        { product_id: product_service.id, value: 10 }
      ]
    )
  end

  let(:bank_transfer_method) do
    PaymentCore::PaymentMethods::BankTransfer.create!(
      display_name: "Bank Transfer",
      bank_name: "Bank Example",
      bank_code: "BANK-EX",
      bank_account_name: "Test Account",
      bank_account_number: "1234567890",
      default_currency: "MYR",
      active: true,
      always_available: true,
      holder: user
    )
  end

  let(:cash_method) do
    PaymentCore::PaymentMethods::Cash.create!(
      display_name: "Cash",
      active: true,
      always_available: true,
      holder: user
    )
  end
  let(:fiuu_method) do
    PaymentCore::PaymentMethods::Fiuu.create!(
      display_name: "Fiuu",
      active: true,
      always_available: true,
      holder: user,
      metadata_merchant_id: "merchant-1",
      metadata_secret_key: "secret-1",
      metadata_verify_key: "verify-1"
    )
  end

  def json_body
    JSON.parse(last_response.body)
  end

  def build_order(name: nil, item:, quantity: 1)
    order = Order.create!(customer: user, name: name)
    order.line_item_line_items.create!(item: item, quantity: quantity, use_item_data: true)
    order.reload
    order
  end

  def build_context(payable)
    PaymentCore.config.payment_method.availability_context_class_constant.new(
      regions: ["ID"],
      currencies: ["MYR"],
      use_cases: ["checkout"],
      payables: [payable]
    )
  end

  def charge_with_cash(order)
    context = build_context(order)
    cash = user.available_payment_methods(context: context).find(&:cash?)
    cash.processor(payer: user, context: context).charge(
      amount: order.total_amount,
      payable: order,
      currency: "MYR",
      metadata: { payment_method_data: {} }
    )
  end

  def ensure_payment_package_method(package, line_item)
    payment_method = user.available_payment_methods.find do |pm|
      pm.payment_package? && pm.package == package
    end
    if payment_method.nil? || payment_method.balance.to_d.zero?
      package.process(user, quantity: line_item.quantity || 1, reference: line_item)
      payment_method = user.available_payment_methods.find do |pm|
        pm.payment_package? && pm.package == package
      end
    end
    payment_method
  end

  def create_payment_package_method
    cash_method
    order = Order.create!(customer: user)
    line_item = order.line_item_line_items.create!(
      item: product_top_up_service_package,
      quantity: 1,
      use_item_data: true
    )
    charge_with_cash(order)
    ensure_payment_package_method(product_top_up_service_package, line_item)
  end

  def create_payment_package_methods(packages)
    cash_method
    packages.map do |package|
      order = Order.create!(customer: user)
      line_item = order.line_item_line_items.create!(
        item: package,
        quantity: 1,
        use_item_data: true
      )
      charge_with_cash(order)
      ensure_payment_package_method(package, line_item)
    end.compact
  end

  context "bank transfer actions" do
    it "charges, requests verification, and verifies via API" do
      order = build_order(item: product_item)
      order.update!(state: "waiting_payment")

      post "/holder/#{holder_type}/#{user.id}/payment_method/#{bank_transfer_method.id}/charge",
        payable_id: order.id,
        payable_type: order.class.name,
        metadata: {}

      expect(last_response.status).to be < 300
      entry = json_body.fetch("data")
      expect(entry["payment_method_id"]).to eq(bank_transfer_method.id)

      post "/holder/#{holder_type}/#{user.id}/payment_method/#{bank_transfer_method.id}/request_verification",
        payable_id: order.id,
        payable_type: order.class.name,
        requested_by: "staff",
        proof: { file_url: "https://example.test/proof.png", note: "transfer" }

      expect(last_response.status).to eq(201)

      post "/holder/#{holder_type}/#{user.id}/payment_method/#{bank_transfer_method.id}/verify",
        payable_id: order.id,
        payable_type: order.class.name,
        accepted: true,
        verified_by: "admin"

      expect(last_response.status).to eq(401)
    end
  end

  context "cash actions" do
    it "charges via API" do
      order = build_order(item: product_item, name: 'goblok')

      post "/holder/#{holder_type}/#{user.id}/payment_method/#{cash_method.id}/charge",
        payable_id: order.id,
        payable_type: order.class.name,
        currency: "MYR"
      expect(last_response.status).to be < 300
      entry = json_body.fetch("data")
      expect(entry["state"]).to eq("succeeded")
    end
  end

  context "fiuu actions" do
    it "builds redirect payload via payment method API" do
      order = build_order(item: product_item)
      order.update!(state: "waiting_payment")

      post "/holder/#{holder_type}/#{user.id}/payment_method/#{fiuu_method.id}/charge",
        payable_id: order.id,
        payable_type: order.class.name

      expect(last_response.status).to be < 300
      entry_payload = json_body.fetch("data")
      entry = PaymentCore::Entry.find(entry_payload.fetch("id"))
      method_data = entry.metadata.payment_method_data
      request_payload = method_data.gateway_request || {}
      order_id = request_payload[:orderid] || request_payload["orderid"]

      expect(method_data.redirect_url).to be_present
      expect(order_id).to eq(entry.number)
    end
  end

  context "payment package actions" do
    it "charges via payment method API" do
      payment_package_method = create_payment_package_method
      order = build_order(item: product_service)

      post "/holder/#{holder_type}/#{user.id}/payment_method/#{payment_package_method.id}/charge",
        payable_id: order.id,
        payable_type: order.class.name,
        currency: "MYR"

      expect(last_response.status).to be < 300
      entry = json_body.fetch("data")
      expect(entry["state"]).to eq("succeeded")
    end

    it "blocks charge when access scopes do not include public" do
      payment_package_method = create_payment_package_method
      order = build_order(item: product_service)

      original_accesses = PaymentCore::Grape::Holder::PaymentMethods.processor_action_accesses
      PaymentCore::Grape::Holder::PaymentMethods.processor_action_accesses = [:staff]
      begin
        post "/holder/#{holder_type}/#{user.id}/payment_method/#{payment_package_method.id}/charge",
          payable_id: order.id,
          payable_type: order.class.name,
          currency: "MYR"
        expect(last_response.status).to eq(401)
      ensure
        PaymentCore::Grape::Holder::PaymentMethods.processor_action_accesses = original_accesses
      end
    end

    it "keeps wrapper processing for mixed orders via payment method API" do
      payment_package_method = create_payment_package_method
      order = Order.create!(customer: user)
      order.line_item_line_items.create!(item: product_item, quantity: 1, use_item_data: true)
      order.line_item_line_items.create!(item: product_service, quantity: 1, use_item_data: true)

      post "/holder/#{holder_type}/#{user.id}/payment_method/#{payment_package_method.id}/charge",
        payable_id: order.id,
        payable_type: order.class.name,
        currency: "MYR"
      expect(last_response.status).to eq(422)
      expect(json_body.fetch("error")).to eq("Unprocessable entity")
    end

    it "keeps wrapper processing for large service orders via payment method API" do
      payment_package_method = create_payment_package_method
      order = build_order(item: product_service, quantity: 20)

      post "/holder/#{holder_type}/#{user.id}/payment_method/#{payment_package_method.id}/charge",
        payable_id: order.id,
        payable_type: order.class.name,
        currency: "MYR"

      expect(last_response.status).to eq(422)
      expect(json_body.fetch("error")).to eq("Unprocessable entity")
    end

    it "refunds via payment method API" do
      payment_package_method = create_payment_package_method
      order = build_order(item: product_service)

      post "/holder/#{holder_type}/#{user.id}/payment_method/#{payment_package_method.id}/charge",
        payable_id: order.id,
        payable_type: order.class.name,
        currency: "MYR"

      expect(last_response.status).to be < 300
      wrapper = json_body.fetch("data")
      charge_entry = Array(wrapper["components"]).first
      expect(charge_entry).to be_present

      post "/holder/#{holder_type}/#{user.id}/payment_method/#{payment_package_method.id}/refund",
        payable_id: charge_entry["id"],
        payable_type: "charge"

      expect(last_response.status).to eq(401)
    end

    it "refunds via payment method API when access is configured" do
      payment_package_method = create_payment_package_method
      order = build_order(item: product_service)

      post "/holder/#{holder_type}/#{user.id}/payment_method/#{payment_package_method.id}/charge",
        payable_id: order.id,
        payable_type: order.class.name,
        currency: "MYR"

      expect(last_response.status).to be < 300
      wrapper = json_body.fetch("data")
      charge_entry = Array(wrapper["components"]).first
      expect(charge_entry).to be_present

      original_accesses = PaymentCore::Processors::PaymentPackage
        .annotations_for(:refund)[:action_accesses]
      original_removals = PaymentCore::Processors::PaymentPackage
        .annotations_for(:refund)[:remove_action_accesses]

      begin
        PaymentCore::Processors::PaymentPackage.action_access(:refund, :public)
        post "/holder/#{holder_type}/#{user.id}/payment_method/#{payment_package_method.id}/refund",
          payable_id: charge_entry["id"],
          payable_type: "charge"

        expect(last_response.status).to be < 300
        entry = json_body.fetch("data")
        expect(entry["state"]).to eq("succeeded")
      ensure
        PaymentCore::Processors::PaymentPackage.clear_annotation_keys_for(
          :refund,
          :action_accesses,
          :remove_action_accesses
        )
        if original_accesses
          PaymentCore::Processors::PaymentPackage.action_access(:refund, *Array(original_accesses))
        end
        if original_removals
          PaymentCore::Processors::PaymentPackage.remove_action_access(:refund, *Array(original_removals))
        end
      end
    end

    it "charges via collective processor action API" do
      payment_package_methods = create_payment_package_methods([
        product_top_up_service_package_small_a,
        product_top_up_service_package_small_b
      ])
      expect(payment_package_methods.size).to eq(2)
      payment_package_methods.each(&:reload)
      order = build_order(item: product_service, quantity: 6, name: 'anjing')
      context_payload = {
        currencies: [
          order.payable_currency,
          payment_package_methods.first.currency,
          payment_package_methods.last.currency
        ].compact.uniq,
        use_cases: ["checkout"],
        payables: { order: [order.id] }
      }

      post "/holder/#{holder_type}/#{user.id}/payment_methods/#{payment_package_methods.first.method_type}/charge",
        payable_id: order.id,
        payable_type: order.class.name,
        payment_method_ids: payment_package_methods.map(&:id),
        currency: "MYR",
        context: context_payload
      expect(last_response.status).to be < 300
      entry = json_body.fetch("data")
      expect(entry["state"]).to eq("succeeded")
      components = Array(entry["components"])
      expect(components.size).to be >= 2
      method_ids = components.map { |component| component["payment_method_id"] }.uniq.sort
      expect(method_ids).to eq(payment_package_methods.map(&:id).sort)
    end

    it "keeps wrapper processing for mixed orders via collective processor action API" do
      payment_package_methods = create_payment_package_methods([
        product_top_up_service_package_small_a,
        product_top_up_service_package_small_b
      ])
      expect(payment_package_methods.size).to eq(2)
      payment_package_methods.each(&:reload)
      order = Order.create!(customer: user)
      order.line_item_line_items.create!(item: product_service, quantity: 1, use_item_data: true)
      order.line_item_line_items.create!(item: product_item, quantity: 1, use_item_data: true)
      context_payload = {
        currencies: [
          order.payable_currency,
          payment_package_methods.first.currency,
          payment_package_methods.last.currency
        ].compact.uniq,
        use_cases: ["checkout"],
        payables: { order: [order.id] }
      }

      post "/holder/#{holder_type}/#{user.id}/payment_methods/#{payment_package_methods.first.method_type}/charge",
        payable_id: order.id,
        payable_type: order.class.name,
        payment_method_ids: payment_package_methods.map(&:id),
        currency: "MYR",
        context: context_payload

      expect(last_response.status).to eq(422)
      expect(json_body.fetch("error")).to eq("Unprocessable entity")
    end
  end
end
