require "rails_helper"

RSpec.describe "Dummy app admin payment methods", type: :request do
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
    original_authenticate_admin = PaymentCore.config.api.authenticate_admin
    admin = admin_user
    PaymentCore.config.api.authenticate_admin = -> { admin }
    example.run
    PaymentCore.config.api.authenticate_admin = original_authenticate_admin
  end

  let(:admin_user) { create(:user, email: "dummy-admin@example.com", name: "Dummy Admin") }
  let(:holder_user) { create(:user, email: "dummy-holder@example.com", name: "Dummy Holder") }

  it "renders the dummy custom payment methods index" do
    create(:cash_payment_method, display_name: "Dummy Cash", holder: holder_user)

    get "/admin/payment_methods"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Payment Method Workspace")
    expect(response.body).to include("Dummy Cash")
  end

  it "renders the dummy custom new page with subtype fields" do
    get "/admin/payment_methods/new", params: { type: PaymentCore::PaymentMethods::BankTransfer.name }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Create Payment Method")
    expect(response.body).to include("Metadata Mapping")
    expect(response.body).to include("payment_method[metadata_bank_name]")
  end

  it "creates payment methods through the dummy controller" do
    post "/admin/payment_methods", params: {
      payment_method: {
        type: PaymentCore::PaymentMethods::BankTransfer.name,
        display_name: "Dummy Bank Transfer",
        active: true,
        always_available: true,
        holder_type: holder_user.class.name,
        holder_id: holder_user.id,
        metadata_bank_name: "Dummy Bank",
        metadata_bank_code: "DUMMY",
        metadata_bank_account_name: "Dummy Holder",
        metadata_bank_account_number: "9876543210"
      }
    }

    expect(response).to redirect_to(%r{/admin/payment_methods/})
    follow_redirect!
    expect(response.body).to include("Payment Method Detail")
    expect(response.body).to include("Dummy Bank Transfer")
  end

  it "updates payment methods through the dummy controller" do
    record = create(:cash_payment_method, display_name: "Old Dummy Cash", holder: holder_user)

    put "/admin/payment_methods/#{record.id}", params: {
      payment_method: {
        display_name: "Updated Dummy Cash",
        holder_type: holder_user.class.name,
        holder_id: holder_user.id
      }
    }

    expect(response).to redirect_to("/admin/payment_methods/#{record.id}")
    follow_redirect!
    expect(response.body).to include("Updated Dummy Cash")
    expect(record.reload.display_name).to eq("Updated Dummy Cash")
  end
end
