require "rails_helper"

RSpec.describe PaymentCore::PaymentMethods::PaymentPackage do
  before(:all) do
    Order; LineItem; User; Product; PaymentPackageProductValue
    Product::Item; Product::Service; Product::PaymentPackage
  end

  before(:each) do
    ensure_default_payment_methods
  end

  let(:customer) { User.create!(email: "user@mail.com", name: "user") }
  let(:product_item) { Product::Item.create!(price: 10, name: "Product Item #1", sku: "1") }
  let(:product_service) { Product::Service.create!(price: 15, name: "Product Service #1", sku: "2") }
  let(:product_top_up_service_package) do
    Product::PaymentPackage.create!(
      price: 20,
      name: "Service Package Top Up",
      sku: "4",
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

  def ensure_default_payment_methods
    builder = PaymentCore.config.payment_method.default_payment_methods_builder
    return unless builder.is_a?(Proc)

    PaymentCore::PaymentMethod.instance_exec(&builder) if PaymentCore::PaymentMethod.none?
  end

  def build_context(payable)
    PaymentCore.config.payment_method.availability_context_class_constant.new(
      regions: ["ID"],
      currencies: ["RM"],
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
      currency: "RM",
      metadata: { payment_method_data: {} }
    )
  end

  def create_payment_package_method
    order = Order.create!(customer: customer)
    order.line_item_line_items.create!(
      item: product_top_up_service_package,
      quantity: 1,
      use_item_data: true
    )
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
