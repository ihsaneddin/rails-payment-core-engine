require "rails_helper"

RSpec.describe "PaymentCore holder API", type: :request do
  include Rack::Test::Methods

  def app
    PaymentCore::Grape::Base
  end

  let(:user) { User.create!(email: "user@example.com", name: "User") }
  let(:holder_type) { user.class.payment_method_holder_api.type }
  let(:cash_method) do
    PaymentCore::PaymentMethods::Cash.create!(
      display_name: "Cash",
      active: true,
      always_available: true,
      holder: user
    )
  end
  let(:entry) do
    PaymentCore::Entries::Charge.create!(
      payment_method: cash_method,
      payer: user,
      amount: 100,
      payment_method_amount: 100,
      currency: "MYR"
    )
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

  it "lists holder entries" do
    entry

    get "/holder/#{holder_type}/#{user.id}/entries"

    expect(last_response.status).to eq(200)
    data = JSON.parse(last_response.body)["data"]
    expect(data.map { |row| row["id"] }).to include(entry.id)
  end

  it "shows a holder entry" do
    entry

    get "/holder/#{holder_type}/#{user.id}/entry/#{entry.id}"

    expect(last_response.status).to eq(200)
    data = JSON.parse(last_response.body)["data"]
    expect(data["id"]).to eq(entry.id)
  end
end
