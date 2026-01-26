require "rails_helper"

RSpec.describe PaymentCore::Gateways::Fiuu do
  include WebMock::API

  let(:gateway) { described_class.new(merchant_id: "merchant-1", secret_key: "secret-1") }

  it "normalizes JSON responses from post_json via WebMock" do
    stub_request(:post, "#{gateway.base_url}/test-endpoint")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { status: "OK", payment_url: "https://pay.fiuu.com/redirect" }.to_json
      )

    response = gateway.post_json("/test-endpoint", payload: { foo: "bar" })
    normalized = gateway.normalize_response(response)

    expect(normalized).to be_a(Hash)
    expect(normalized[:status]).to eq("OK")
    expect(normalized[:payment_url]).to eq("https://pay.fiuu.com/redirect")
    expect(normalized[:http_code]).to eq(200)
  end
end
