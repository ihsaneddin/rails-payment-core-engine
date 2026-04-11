require "rails_helper"

RSpec.describe "PaymentCore holder payment methods API", type: :request do
  include Rack::Test::Methods

  def app
    PaymentCore::Grape::Base.draw
  end

  before(:all) do
    Order; LineItem; User; Product; PaymentPackageProductValue
    Product::Item; Product::Service; Product::PaymentPackage
  end

  let(:user) { create(:user, email: "user@example.com", name: "User") }
  let(:holder_type) { user.class.payment_method_holder_config.type }
  let(:cash_method) do
    create(:cash_payment_method, display_name: "Cash", holder: user)
  end

  it "lists holder payment methods" do
    cash_method

    get "/holder/#{holder_type}/#{user.id}/payment_methods"

    expect(last_response.status).to eq(200)
    data = JSON.parse(last_response.body)["data"]
    expect(data).to be_a(Array)
    expect(data.map { |row| row["method_type"] }).to include("cash")
  end

  it "lists holder available payment methods" do
    cash_method

    get "/holder/#{holder_type}/#{user.id}/payment_methods/available"

    expect(last_response.status).to eq(200)
    data = JSON.parse(last_response.body)["data"]
    expect(data.map { |row| row["method_type"] }).to include("cash")
  end
end
