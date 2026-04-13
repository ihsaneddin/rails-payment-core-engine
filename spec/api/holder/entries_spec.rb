require "rails_helper"

RSpec.describe "PaymentCore holder entries API", type: :request do
  include Rack::Test::Methods

  def app
    PaymentCore::Grape::Base.draw(draw_options)
  end

  before(:all) do
    Order; LineItem; User; Product; PaymentPackageProductValue
    Product::Item; Product::Service; Product::PaymentPackage
  end

  let(:user) { create(:user, email: "user@example.com", name: "User") }
  let(:holder_type) { user.class.payment_method_holder_config.type }
  let(:draw_options) { {} }
  let(:product_item) { create(:product_item, price: 10, name: "Product Item", sku: "item-1") }
  let(:cash_method) do
    create(:cash_payment_method, display_name: "Cash", holder: user)
  end
  let(:entry) do
    create(:cash_charge_entry, holder: user, payment_method: cash_method, item: product_item)
  end

  it "lists holder entries" do
    entry

    get "#{holder_prefix}/#{holder_type}/#{user.id}/entries"

    expect(last_response.status).to eq(200)
    data = JSON.parse(last_response.body)["data"]
    expect(data.map { |row| row["id"] }).to include(entry.id)
  end

  it "shows a holder entry" do
    entry

    get "#{holder_prefix}/#{holder_type}/#{user.id}/entry/#{entry.id}"

    expect(last_response.status).to eq(200)
    data = JSON.parse(last_response.body)["data"]
    expect(data["id"]).to eq(entry.id)
  end

  context "when namespace is provided" do
    let(:draw_options) { { namespace: :platform, holder: { namespace: "wallet_holder/:holder_type/:holder_id" } } }

    def holder_prefix
      "/platform/wallet_holder"
    end

    it "does not keep the old holder entry path" do
      entry

      get "/holder/#{holder_type}/#{user.id}/entries"

      expect(last_response.status).to eq(404)
    end
  end

  def holder_prefix
    "/holder"
  end
end
