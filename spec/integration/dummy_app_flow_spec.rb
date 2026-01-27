require "rails_helper"

RSpec.describe "PaymentCore dummy app flows" do
  before(:all) do
    Order; LineItem; User; Product; PaymentPackageProductValue
    Product::Item; Product::Service; Product::PaymentPackage
    PaymentCore::Attributes::Entries::MethodData::FiuuMethod
  end

  before(:each) do
    ensure_default_payment_methods
  end

  let(:customer) { User.create!(email: "user@mail.com", name: "user") }
  let(:product_item) { Product::Item.create!(price: 10, name: "Product Item #1", sku: "1") }
  let(:product_service) { Product::Service.create!(price: 15, name: "Product Service #1", sku: "2") }
  let(:product_top_up_wallet) do
    Product::PaymentPackage.create!(
      price: 45,
      name: "Ewallet Top Up",
      sku: "3",
      amount_per_quantity: 50,
      allow_purchase_on_any_item: true,
      will_be_expired: false,
      currency: "Ringgit Malaysian",
      custom_value: false
    )
  end
  let(:product_top_up_service_package) do
    Product::PaymentPackage.create!(
      price: 20,
      name: "Service Package Top Up",
      sku: "4",
      amount_per_quantity: 100,
      allow_purchase_on_any_item: false,
      disallow_purchase_on_item_ids: [product_top_up_wallet.id, product_item.id],
      will_be_expired: false,
      currency: "Service Package",
      custom_value: true,
      product_values_attributes: [
        { product_id: product_service.id, value: 10 }
      ]
    )
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
    cash = customer.available_payment_methods(context: context).find(&:cash?)
    cash.processor(payer: customer, context: context).charge(
      amount: order.total_amount,
      payable: order,
      currency: "MYR",
      metadata: {
        payment_method_data: {}
      }
    )
  end

  def top_up_accounts
    order = Order.create!(customer: customer)
    order.line_item_line_items.create!(item: product_item, quantity: 1, use_item_data: true)
    order.line_item_line_items.create!(item: product_top_up_wallet, quantity: 1, use_item_data: true)
    order.line_item_line_items.create!(item: product_top_up_service_package, quantity: 1, use_item_data: true)

    charge_with_cash(order)

    wallet_account = customer.current_ewallet
      .get_accounts_of(product_top_up_wallet.get_or_create_ewallet_currency).first
    service_account = customer.current_ewallet
      .get_accounts_of(product_top_up_service_package.get_or_create_ewallet_currency).first

    [order, wallet_account, service_account]
  end

  def service_package_method
    customer.available_payment_methods.find { |pm| pm.payment_package? && pm.package.custom_value }
  end

  def ensure_default_payment_methods
    builder = PaymentCore.config.payment_method.default_payment_methods_builder
    return unless builder.is_a?(Proc)

    PaymentCore::PaymentMethod.instance_exec(&builder) if PaymentCore::PaymentMethod.none?
  end

  it "completes cash checkout and tops up accounts" do
    order, wallet_account, service_account = top_up_accounts

    expect(order.reload.state).to eq("completed")
    expect(wallet_account.balance).to eq(product_top_up_wallet.amount_per_quantity)
    expect(service_account.balance).to eq(product_top_up_service_package.amount_per_quantity)
  end

  it "rejects payment package when order has non-eligible items" do
    top_up_accounts

    order = Order.create!(customer: customer, name: "bedul")
    order.line_item_line_items.create!(item: product_item, quantity: 1, use_item_data: true)
    order.line_item_line_items.create!(item: product_service, quantity: 1, use_item_data: true)

    context = build_context(order)
    package_method = customer.available_payment_methods(context: context)
      .find { |pm| pm.payment_package? && pm.package.custom_value }
    expect(package_method).to be_present

    entry = package_method.processor.charge(
      amount: order.total_amount,
      payable: order,
      currency: "MYR",
      metadata: { payment_method_data: {} }
    )
    expect(entry).to be_a(PaymentCore::Entries::Wrapper)
    expect(entry.errors.any?).to eq(true)
    expect(entry.succeeded?).to eq(false)
    expect(entry.components.sum(&:amount)).to be < entry.amount
  end

  it "charges service-only orders with payment package" do
    _order, _wallet_account, service_account = top_up_accounts
    package_method = service_package_method

    order = Order.create!(customer: customer, name: "service-order")
    line_item = order.line_item_line_items.create!(item: product_service, quantity: 1, use_item_data: true)
    previous_balance = service_account.reload.balance

    entry = package_method.processor.charge(
      amount: order.total_amount,
      payable: order,
      currency: "MYR",
      metadata: { payment_method_data: {} }
    )

    expect(entry.errors).to be_empty
    expect(order.reload.state).to eq("completed")

    expected_balance = previous_balance - (
      line_item.quantity * product_top_up_service_package.get_value_of_product(product_service)
    )
    expect(service_account.reload.balance).to eq(expected_balance)
  end

  it "keeps wrapper processing when service order exceeds package coverage" do
    _order, _wallet_account, _service_account = top_up_accounts
    package_method = service_package_method

    order = Order.create!(customer: customer, name: "service-order-large")
    order.line_item_line_items.create!(item: product_service, quantity: 20, use_item_data: true)

    entry = package_method.processor.charge(
      amount: order.total_amount,
      payable: order,
      currency: "MYR",
      metadata: { payment_method_data: {} }
    )

    expect(entry).to be_a(PaymentCore::Entries::Wrapper)
    expect(entry.errors).to be_present
    expect(entry.state).not_to eq("succeeded")
    expect(entry.components.sum(&:amount)).to be < entry.amount
  end

  it "builds fiuu redirect payload and url" do
    order = Order.create!(customer: customer, name: "fiuu-order", state: "cart")
    order.line_item_line_items.create!(item: product_item, quantity: 1, use_item_data: true)
    order.update!(state: "waiting_payment")

    payment_method = PaymentCore::PaymentMethods::Fiuu.create!(
      display_name: "Fiuu",
      active: true,
      always_available: true,
      metadata_merchant_id: "merchant-1",
      metadata_secret_key: "secret-1",
      metadata_verify_key: "verify-1"
    )
    order.reload
    context = build_context(order)
    entry = payment_method.processor(payer: customer, context: context).charge(
      payable: order
    )

    method_data = entry.metadata.payment_method_data
    payload = method_data.gateway_request || {}
    order_id = payload[:orderid] || payload["orderid"]

    expect(method_data.redirect_url).to be_present
    expect(order_id).to eq(entry.number)
  end

  it "creates api scenario orders" do
    order = Order.create!(customer: customer)
    order.line_item_line_items.create!(item: product_item, quantity: 1, use_item_data: true)
    expect(order).to be_persisted

    order = Order.create!(customer: customer)
    order.line_item_line_items.create!(item: product_item, quantity: 1, use_item_data: true)
    order.line_item_line_items.create!(item: product_service, quantity: 1, use_item_data: true)
    expect(order).to be_persisted

    order = Order.create!(customer: customer)
    order.line_item_line_items.create!(item: product_service, quantity: 1, use_item_data: true)
    expect(order).to be_persisted

    order = Order.create!(customer: customer)
    order.line_item_line_items.create!(item: product_service, quantity: 20, use_item_data: true)
    expect(order).to be_persisted

    order = Order.create!(customer: customer)
    order.line_item_line_items.create!(item: product_service, quantity: 1, use_item_data: true)
    order.line_item_line_items.create!(item: product_item, quantity: 1, use_item_data: true)
    expect(order).to be_persisted
  end
end
