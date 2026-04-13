require "rails_helper"

RSpec.describe "PaymentCore admin entries API", type: :request do
  include Rack::Test::Methods

  def app
    PaymentCore::Grape::Base.draw(draw_options)
  end

  def json_body
    JSON.parse(last_response.body)
  end

  def member_processor_path_for(record, action)
    "#{admin_prefix}/payment_method/#{record.id}/#{action}"
  end

  let(:admin_user) { create(:user, email: "admin@example.com", name: "Admin") }
  let(:holder_user) { create(:user, email: "holder@example.com", name: "Holder") }
  let(:draw_options) { {} }
  let(:cash_method) do
    create(:cash_payment_method, display_name: "Cash", holder: holder_user)
  end
  let(:product_item) { create(:product_item, price: 10, name: "Product Item", sku: "item-1") }
  let(:entry) do
    order = create(:order, customer: holder_user, name: "admin-entries", item: product_item)

    post member_processor_path_for(cash_method, "charge"),
      payable_id: order.id,
      payable_type: order.class.name,
      currency: "MYR"

    PaymentCore::Entry.find(json_body.fetch("data").fetch("id"))
  end

  before(:all) do
    Order; LineItem; User; Product; PaymentPackageProductValue
    Product::Item; Product::Service; Product::PaymentPackage
  end

  before do
    allow_any_instance_of(Ewallet::Subscribers::EntrySubscriber).to receive(:entry_event_callback)
  end

  around do |example|
    original_authenticate_admin = PaymentCore.config.grape_api.authenticate_admin
    admin = admin_user
    PaymentCore.config.grape_api.authenticate_admin = -> { admin }
    example.run
    PaymentCore.config.grape_api.authenticate_admin = original_authenticate_admin
  end

  it "lists entries via admin endpoints" do
    entry
    get "#{admin_prefix}/entries"

    expect(last_response.status).to eq(200)
    expect(json_body.fetch("data").map { |row| row["id"] }).to include(entry.id)
  end

  it "shows entries via admin endpoints" do
    entry
    get "#{admin_prefix}/entry/#{entry.id}"

    expect(last_response.status).to eq(200)
    expect(json_body.fetch("data").fetch("id")).to eq(entry.id)
  end

  context "when namespace is provided" do
    let(:draw_options) { { namespace: :platform, admin: { namespace: :staff } } }

    def admin_prefix
      "/platform/staff"
    end

    it "does not keep the old admin entries path" do
      entry

      get "/admin/entries"

      expect(last_response.status).to eq(404)
    end
  end

  def admin_prefix
    "/admin"
  end
end
