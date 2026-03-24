require "rails_helper"

RSpec.describe "PaymentCore holder entries ActionController", type: :request do
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
      example.run
    end
  end

  let(:user) { create(:user, email: "holder@example.com", name: "Holder") }
  let(:holder_type) { user.class.payment_method_holder_api.type }
  let(:cash_method) { create(:cash_payment_method, display_name: "Cash", holder: user) }
  let(:product_item) { create(:product_item, price: 10, name: "Product Item", sku: "item-1") }

  before do
    allow_any_instance_of(Ewallet::Subscribers::EntrySubscriber).to receive(:entry_event_callback)
  end

  def build_order(item:)
    create(:order, customer: user, item: item, quantity: 1)
  end

  def create_entry_via_holder_flow
    order = build_order(item: product_item)
    post "/payment_core/holder/#{holder_type}/#{user.id}/payment_method/#{cash_method.id}/charge", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      currency: "MYR"
    }
    PaymentCore::Entry.order(:id).last
  end

  it "renders holder entries index" do
    entry = create_entry_via_holder_flow

    get "/payment_core/holder/#{holder_type}/#{user.id}/entries"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Entries")
    expect(response.body).to include(entry.class.entry_type)
  end

  it "renders holder entry show page" do
    entry = create_entry_via_holder_flow

    get "/payment_core/holder/#{holder_type}/#{user.id}/entry/#{entry.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Entry")
    expect(response.body).to include(entry.class.entry_type)
  end
end
