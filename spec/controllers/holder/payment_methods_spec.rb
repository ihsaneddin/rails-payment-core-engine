require "rails_helper"

RSpec.describe "PaymentCore holder payment methods ActionController", type: :request do
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

  let(:user) { create(:user, email: "user@example.com", name: "User") }
  let(:holder_type) { user.class.payment_method_holder_api.type }
  let(:cash_method) { create(:cash_payment_method, display_name: "Cash", holder: user) }
  let(:bank_transfer_method) { create(:bank_transfer_payment_method, display_name: "Bank Transfer", holder: user) }
  let(:fiuu_method) { create(:fiuu_payment_method, display_name: "Fiuu", holder: user) }
  let(:product_item) { create(:product_item, price: 10, name: "Product Item", sku: "item-1") }

  before do
    allow_any_instance_of(Ewallet::Subscribers::EntrySubscriber).to receive(:entry_event_callback)
  end

  def build_order(name: nil, item:, quantity: 1)
    create(:order, customer: user, name: name, item: item, quantity: quantity)
  end

  def holder_payment_methods_path
    "/payment_core/holder/#{holder_type}/#{user.id}/payment_methods"
  end

  def holder_payment_method_path(record)
    "/payment_core/holder/#{holder_type}/#{user.id}/payment_method/#{record.id}"
  end

  it "renders holder payment methods index" do
    cash_method

    get holder_payment_methods_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Payment Methods")
    expect(response.body).to include("Cash")
  end

  it "renders holder available payment methods page" do
    cash_method

    get "#{holder_payment_methods_path}/available"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Available Payment Methods")
    expect(response.body).to include("Cash")
  end

  it "renders holder payment method show page" do
    get holder_payment_method_path(cash_method)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Payment Method")
    expect(response.body).to include("Cash")
  end

  it "renders public cash processor action form" do
    get holder_payment_method_path(cash_method)

    expect(response.body).to include("Charge")
    expect(response.body).to include("payable_type")
    expect(response.body).to include("payable_id")
  end

  it "does not render private verify action for holder bank transfer" do
    get holder_payment_method_path(bank_transfer_method)

    expect(response.body).to include("Request verification")
    expect(response.body).not_to include("Verify")
  end

  it "charges cash through holder action controller flow" do
    order = build_order(item: product_item, name: "holder-cash")

    post "#{holder_payment_method_path(cash_method)}/charge", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      currency: "MYR"
    }

    expect(response).to redirect_to(%r{/payment_core/holder/#{holder_type}/#{user.id}/entry/})
    follow_redirect!
    expect(response.body).to include("Entry")
    expect(response.body).to include("succeeded")
  end

  it "charges bank transfer through holder action controller flow" do
    order = build_order(item: product_item)
    order.update!(state: "waiting_payment")

    post "#{holder_payment_method_path(bank_transfer_method)}/charge", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      metadata_json: "{}"
    }

    expect(response).to redirect_to(%r{/payment_core/holder/#{holder_type}/#{user.id}/entry/})
    follow_redirect!
    expect(response.body).to include("Entry")
    expect(response.body).to include("Bank Transfer")
  end

  it "requests bank transfer verification through holder action controller flow" do
    order = build_order(item: product_item)
    order.update!(state: "waiting_payment")

    post "#{holder_payment_method_path(bank_transfer_method)}/charge", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      metadata_json: "{}"
    }

    post "#{holder_payment_method_path(bank_transfer_method)}/request_verification", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      requested_by: "holder",
      proof: {
        file_url: "https://example.test/proof.png",
        note: "transfer"
      }
    }

    expect(response).to redirect_to(%r{/payment_core/holder/#{holder_type}/#{user.id}/entry/})
  end

  it "charges fiuu through holder action controller flow" do
    order = build_order(item: product_item)
    order.update!(state: "waiting_payment")

    post "#{holder_payment_method_path(fiuu_method)}/charge", params: {
      payable_id: order.id,
      payable_type: order.class.name
    }

    expect(response).to redirect_to(%r{/payment_core/holder/#{holder_type}/#{user.id}/entry/})
    entry = PaymentCore::Entry.order(:id).last
    expect(entry.metadata.payment_method_data.redirect_url).to be_present
  end
end
