require "rails_helper"

RSpec.describe "PaymentCore admin payment methods ActionController", type: :request do
  ACTION_CONTROLLER_PAYMENT_METHOD_CLASSES = [
    "PaymentCore::PaymentMethods::Cash",
    "PaymentCore::PaymentMethods::BankTransfer",
    "PaymentCore::PaymentMethods::Fiuu"
  ].filter_map(&:safe_constantize).freeze

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
  let(:product_item) { create(:product_item, price: 10, name: "Product Item", sku: "item-1") }

  before do
    allow_any_instance_of(Ewallet::Subscribers::EntrySubscriber).to receive(:entry_event_callback)
  end

  def build_order(item:)
    create(:order, customer: holder_user, item: item, quantity: 1)
  end

  def existing_record_for(klass)
    case klass.method_type.to_s
    when "cash"
      create(:cash_payment_method, display_name: "Admin Cash", holder: holder_user)
    when "bank_transfer"
      create(:bank_transfer_payment_method, display_name: "Admin Bank Transfer", holder: holder_user)
    when "fiuu"
      create(:fiuu_payment_method, display_name: "Admin Fiuu", holder: holder_user)
    else
      raise "Missing factory for #{klass.name}"
    end
  end

  def create_payload_for(klass)
    base = {
      type: klass.name,
      display_name: "Created #{klass.method_type.titleize}",
      active: true,
      always_available: true,
      holder_type: holder_user.class.name,
      holder_id: holder_user.id
    }

    case klass.method_type.to_s
    when "cash"
      base
    when "bank_transfer"
      base.merge(
        metadata_bank_name: "Bank Example",
        metadata_bank_code: "BANK-EX",
        metadata_bank_account_name: "Test Account",
        metadata_bank_account_number: "1234567890"
      )
    when "fiuu"
      base.merge(
        metadata_merchant_id: "merchant-1",
        metadata_secret_key: "secret-1",
        metadata_verify_key: "verify-1",
        metadata_flow: "redirect"
      )
    else
      raise "Missing payload for #{klass.name}"
    end
  end

  it "renders admin payment methods index" do
    existing_record_for(PaymentCore::PaymentMethods::Cash)

    get "/payment_core/admin/payment_methods"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Payment Methods")
    expect(response.body).to include("Admin Cash")
  end

  it "renders admin payment method new page with type selector" do
    get "/payment_core/admin/payment_methods/new", params: { type: PaymentCore::PaymentMethods::BankTransfer.name }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("New Payment Method")
    expect(response.body).to include("payment_method[metadata_bank_name]")
    expect(response.body).to include("payment_method[availability_rules][regions]")
  end

  ACTION_CONTROLLER_PAYMENT_METHOD_CLASSES.each do |payment_method_class|
    it "creates #{payment_method_class.method_type} through admin action controller" do
      post "/payment_core/admin/payment_methods", params: {
        payment_method: create_payload_for(payment_method_class)
      }

      expect(response).to redirect_to(%r{/payment_core/admin/payment_methods/})
      follow_redirect!
      expect(response.body).to include(payment_method_class.method_type)
    end
  end

  it "renders admin payment method show page" do
    record = existing_record_for(PaymentCore::PaymentMethods::Cash)

    get "/payment_core/admin/payment_methods/#{record.id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Payment Method")
    expect(response.body).to include("Admin Cash")
  end

  it "renders all processor actions for admin bank transfer" do
    record = existing_record_for(PaymentCore::PaymentMethods::BankTransfer)

    get "/payment_core/admin/payment_methods/#{record.id}"

    expect(response.body).to include("Charge")
    expect(response.body).to include("Request verification")
    expect(response.body).to include("Verify")
  end

  it "updates payment method through admin action controller" do
    record = existing_record_for(PaymentCore::PaymentMethods::Cash)

    put "/payment_core/admin/payment_methods/#{record.id}", params: {
      payment_method: {
        display_name: "Updated Cash",
        holder_type: holder_user.class.name,
        holder_id: holder_user.id
      }
    }

    expect(response).to redirect_to("/payment_core/admin/payment_methods/#{record.id}")
    expect(record.reload.display_name).to eq("Updated Cash")
  end

  it "destroys payment method through admin action controller" do
    record = existing_record_for(PaymentCore::PaymentMethods::Cash)

    delete "/payment_core/admin/payment_methods/#{record.id}"

    expect(response).to redirect_to("/payment_core/admin/payment_methods")
    expect(PaymentCore::PaymentMethod.find_by(id: record.id)).to be_nil
  end

  it "charges cash through admin action controller flow" do
    cash_method = existing_record_for(PaymentCore::PaymentMethods::Cash)
    order = build_order(item: product_item)

    post "/payment_core/admin/payment_method/#{cash_method.id}/charge", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      currency: "MYR"
    }

    expect(response).to redirect_to(%r{/payment_core/admin/entry/})
    follow_redirect!
    expect(response.body).to include("Entry")
    expect(response.body).to include("succeeded")
  end

  it "charges bank transfer through admin action controller flow" do
    method = existing_record_for(PaymentCore::PaymentMethods::BankTransfer)
    order = build_order(item: product_item)
    order.update!(state: "waiting_payment")

    post "/payment_core/admin/payment_method/#{method.id}/charge", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      metadata_json: "{}"
    }

    expect(response).to redirect_to(%r{/payment_core/admin/entry/})
  end

  it "requests bank transfer verification through admin action controller flow" do
    method = existing_record_for(PaymentCore::PaymentMethods::BankTransfer)
    order = build_order(item: product_item)
    order.update!(state: "waiting_payment")

    post "/payment_core/admin/payment_method/#{method.id}/charge", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      metadata_json: "{}"
    }

    post "/payment_core/admin/payment_method/#{method.id}/request_verification", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      requested_by: "staff",
      proof: {
        file_url: "https://example.test/proof.png",
        note: "transfer"
      }
    }

    expect(response).to redirect_to(%r{/payment_core/admin/entry/})
  end

  it "verifies bank transfer through admin action controller flow" do
    method = existing_record_for(PaymentCore::PaymentMethods::BankTransfer)
    order = build_order(item: product_item)
    order.update!(state: "waiting_payment")

    post "/payment_core/admin/payment_method/#{method.id}/charge", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      metadata_json: "{}"
    }
    post "/payment_core/admin/payment_method/#{method.id}/request_verification", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      requested_by: "staff",
      proof: {
        file_url: "https://example.test/proof.png",
        note: "transfer"
      }
    }

    post "/payment_core/admin/payment_method/#{method.id}/verify", params: {
      payable_id: order.id,
      payable_type: order.class.name,
      accepted: "1",
      verified_by: "admin"
    }

    expect(response).to redirect_to(%r{/payment_core/admin/entry/})
    follow_redirect!
    expect(response.body).to include("succeeded")
  end

  it "charges fiuu through admin action controller flow" do
    fiuu_method = existing_record_for(PaymentCore::PaymentMethods::Fiuu)
    order = build_order(item: product_item)
    order.update!(state: "waiting_payment")

    post "/payment_core/admin/payment_method/#{fiuu_method.id}/charge", params: {
      payable_id: order.id,
      payable_type: order.class.name
    }

    expect(response).to redirect_to(%r{/payment_core/admin/entry/})
    entry = PaymentCore::Entry.order(:id).last
    expect(entry.metadata.payment_method_data.redirect_url).to be_present
  end
end
