require "rails_helper"
require "payment_core/grape/payable"

RSpec.describe "PaymentCore payable entries API", type: :request do
  include Rack::Test::Methods

  def app
    PaymentCore::Grape::Payable::Base.draw(draw_options) do
      helpers do
        def payable
          @payable ||= Order.find(params[:payable_id])
        end
      end
    end
  end

  before(:all) do
    Order; LineItem; User; Product; PaymentPackageProductValue
    Product::Item; Product::Service; Product::PaymentPackage
  end

  let(:draw_options) { {} }
  let(:user) { create(:user, email: "user@example.com", name: "User") }
  let(:product_item) { create(:product_item, price: 10, name: "Product Item", sku: "item-1") }
  let(:cash_method) do
    create(:cash_payment_method, display_name: "Cash", holder: user)
  end
  let(:payable) do
    create(:order, customer: user, name: "payable-order", item: product_item)
  end
  let(:context) { build(:payment_method_availability_context, payables: [payable]) }
  let(:processor) { cash_method.processor(payer: user, context: context) }
  let(:payable_type) { payable.class.name }
  let(:entry) do
    processor.charge(payable: payable)
  end

  it "lists payable entries" do
    entry

    get "#{payable_prefix}/#{payable_type}/#{payable.id}/entries"

    expect(last_response.status).to eq(200)
    data = JSON.parse(last_response.body)["data"]
    expect(data.map { |row| row["id"] }).to include(entry.id)
  end

  context "when namespace is provided" do
    let(:draw_options) { { namespace: "billable/:payable_type/:payable_id" } }

    def payable_prefix
      "/billable"
    end

    it "does not keep the old payable namespace" do
      entry

      get "/payable/#{payable_type}/#{payable.id}/entries"

      expect(last_response.status).to eq(404)
    end
  end

  def payable_prefix
    "/payable"
  end
end
