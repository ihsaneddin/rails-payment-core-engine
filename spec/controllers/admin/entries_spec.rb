require "rails_helper"

RSpec.describe "PaymentCore admin entries ActionController", type: :request do
  before(:all) do
    Order
    LineItem
    User
    Product
    PaymentPackageProductValue
    Product::Item
    Product::Service
    Product::PaymentPackage
  end

  around do |example|
    with_action_controller_api do
      original_authenticate_admin = PaymentCore.config.api.authenticate_admin
      admin = admin_user
      PaymentCore.config.api.authenticate_admin = -> { admin }
      example.run
      PaymentCore.config.api.authenticate_admin = original_authenticate_admin
    end
  end

  let(:admin_user) { create(:user, email: "admin@example.com", name: "Admin") }
  let(:holder_user) { create(:user, email: "holder@example.com", name: "Holder") }
  let(:cash_method) { create(:cash_payment_method, display_name: "Cash", holder: holder_user) }
  let(:product_item) { create(:product_item, price: 10, name: "Product Item", sku: "item-1") }

  before do
    allow_any_instance_of(Ewallet::Subscribers::EntrySubscriber).to receive(:entry_event_callback)
  end

  def create_entry_via_admin_flow
    order = create(:order, customer: holder_user, item: product_item, quantity: 1)
    post "/payment_core/admin/payment_method/#{cash_method.id}/charge", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      currency: "MYR"
    }
    PaymentCore::Entry.order(:id).last
  end

  it "renders admin entries index" do
    entry = create_entry_via_admin_flow

    get "/payment_core/admin/entries"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Entries")
    expect(response.body).to include(entry.class.entry_type)
  end

  it "renders admin entry show page" do
    entry = create_entry_via_admin_flow

    get "/payment_core/admin/entry/#{entry.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Entry")
    expect(response.body).to include(entry.class.entry_type)
  end
end
