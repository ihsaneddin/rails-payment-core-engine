require "rails_helper"

RSpec.describe PaymentCore::PaymentMethods::PaymentPackage do
  before(:all) do
    Order; LineItem; User; Product; PaymentPackageProductValue
    Product::Item; Product::Service; Product::PaymentPackage
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
  let(:product_top_up_service_package) do
    create(
      :product_payment_package,
      price: 20,
      name: "Service Package Top Up",
      sku: "4",
      amount_per_quantity: 100,
      allow_purchase_on_any_item: false,
      disallow_purchase_on_item_ids: [product_item.id],
      will_be_expired: false,
      currency: "Service Package",
      custom_value: true,
      product_values: [
        { product_id: product_service.id, value: 10 }
      ]
    )
  end

  def ensure_default_payment_methods
    builder = PaymentCore.config.payment_method.default_payment_methods_builder
    return unless builder.is_a?(Proc)

    PaymentCore::PaymentMethod.instance_exec(&builder) if PaymentCore::PaymentMethod.none?
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
    cash_method.processor(payer: customer, context: context).charge(
      amount: order.total_amount,
      payable: order,
      currency: "MYR",
      metadata: { payment_method_data: {} }
    )
  end

  def create_payment_package_method
    order = create(:order, customer: customer, item: product_top_up_service_package)
    charge_with_cash(order)

    customer.available_payment_methods.find { |pm| pm.payment_package? && pm.package.custom_value }
  end

  it "syncs metadata from ewallet account reference" do
    payment_method = create_payment_package_method
    expect(payment_method).to be_present

    account = customer.current_ewallet
      .get_accounts_of(product_top_up_service_package.get_or_create_ewallet_currency).first

    expect(payment_method.balance).to eq(account.balance)
    expect(payment_method.currency).to eq(account.currency.name)
  end
end
