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

  let(:customer) { create(:user, email: "user@mail.com", name: "user") }
  let!(:cash_method) do
    create(:cash_payment_method, display_name: "Cash", holder: nil)
  end
  let(:product_item) { create(:product_item, price: 10, name: "Product Item #1", sku: "1") }
  let(:product_service) { create(:product_service, price: 15, name: "Product Service #1", sku: "2") }
  let(:product_top_up_wallet) do
    create(
      :product_payment_package,
      :wallet_top_up,
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
    create(
      :product_payment_package,
      price: 20,
      name: "Service Package Top Up",
      sku: "4",
      amount_per_quantity: 100,
      allow_purchase_on_any_item: false,
      disallow_purchase_on_item_ids: [product_top_up_wallet.id, product_item.id],
      will_be_expired: false,
      currency: "Service Package",
      custom_value: true,
      product_values: [
        { product_id: product_service.id, value: 10 }
      ]
    )
  end

  def build_context(payable)
    build(:payment_method_availability_context, payables: [payable])
  end

  def charge_with_cash(order)
    context = build_context(order)
    cash_method.processor(payer: customer, context: context).charge(
      amount: order.total_amount,
      payable: order,
      currency: "MYR",
      metadata: {
        payment_method_data: {}
      }
    )
  end

  def top_up_accounts
    order = create(:order, customer: customer, name: "anjing", state: "waiting_payment")
    create(:line_item, order: order, item: product_item, quantity: 1)
    create(:line_item, order: order, item: product_top_up_wallet, quantity: 1)
    create(:line_item, order: order, item: product_top_up_service_package, quantity: 1)

    charge_with_cash(order)

    wallet_account = customer.current_ewallet_account(product_top_up_wallet.get_or_create_ewallet_currency)
    service_account = customer.current_ewallet_account(product_top_up_service_package.get_or_create_ewallet_currency)

    [order, wallet_account, service_account]
  end

  def service_package_method
    customer.payment_methods.reset if customer.respond_to?(:payment_methods)
    customer.available_payment_methods.find { |pm| pm.payment_package? && pm.package&.custom_value }
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

    order = create(:order, customer: customer, name: "bedul")
    create(:line_item, order: order, item: product_item, quantity: 1)
    create(:line_item, order: order, item: product_service, quantity: 1)

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

    order = create(:order, customer: customer, name: "service-order", item: product_service)
    line_item = order.line_item_line_items.first
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

    order = create(:order, customer: customer, name: "service-order-large", item: product_service, quantity: 20)

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
    order = create(:order, customer: customer, name: "fiuu-order", state: "cart", item: product_item)
    order.update!(state: "waiting_payment")

    payment_method = create(
      :fiuu_payment_method,
      display_name: "Fiuu",
      active: true,
      always_available: true,
      holder: nil,
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
    order = create(:order, customer: customer, item: product_item)
    expect(order).to be_persisted

    order = create(
      :order,
      customer: customer,
      line_items: [
        { item: product_item, quantity: 1 },
        { item: product_service, quantity: 1 }
      ]
    )
    expect(order).to be_persisted

    order = create(:order, customer: customer, item: product_service)
    expect(order).to be_persisted

    order = create(:order, customer: customer, item: product_service, quantity: 20)
    expect(order).to be_persisted

    order = create(
      :order,
      customer: customer,
      line_items: [
        { item: product_service, quantity: 1 },
        { item: product_item, quantity: 1 }
      ]
    )
    expect(order).to be_persisted
  end
end
