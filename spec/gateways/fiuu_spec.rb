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

  it "queries entry info by transaction ID and returns success status" do
    amount = "100.00"
    tx_id = "TX123"
    verify_key = "verify-1"
    expected_skey = Digest::MD5.hexdigest("#{tx_id}merchant-1#{verify_key}#{amount}")

    stub_request(:post, gateway.send(:api_url, "/RMS/q_by_tid.php"))
      .with { |req|
        params = CGI.parse(req.body.to_s)
        params["txID"]&.first == tx_id &&
          params["domain"]&.first == "merchant-1" &&
          params["amount"]&.first == amount &&
          params["skey"]&.first == expected_skey &&
          params["type"]&.first == "2"
      }
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          "StatCode" => "00",
          "StatName" => "captured",
          "TranID" => tx_id,
          "Amount" => amount,
          "Domain" => "merchant-1",
          "OrderID" => "ORD-1",
          "Currency" => "MYR"
        }.to_json
      )

    response = gateway.entry_info(transaction_id: tx_id, amount: amount, verify_key: verify_key)

    expect(response[:StatCode]).to eq("00")
    expect(response[:TranID]).to eq(tx_id)
  end

  it "queries entry info by order ID and returns failed status" do
    amount = "120.00"
    order_id = "ORD-FAIL"
    verify_key = "verify-1"
    expected_skey = Digest::MD5.hexdigest("#{order_id}merchant-1#{verify_key}#{amount}")

    stub_request(:post, gateway.send(:api_url, "/RMS/query/q_by_oid.php"))
      .with { |req|
        params = CGI.parse(req.body.to_s)
        params["oID"]&.first == order_id &&
          params["domain"]&.first == "merchant-1" &&
          params["amount"]&.first == amount &&
          params["skey"]&.first == expected_skey &&
          params["type"]&.first == "2"
      }
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          "StatCode" => "11",
          "StatName" => "failed",
          "OrderID" => order_id,
          "Amount" => amount,
          "Domain" => "merchant-1",
          "Currency" => "MYR"
        }.to_json
      )

    response = gateway.entry_info(order_id: order_id, amount: amount, verify_key: verify_key)

    expect(response[:StatCode]).to eq("11")
    expect(response[:OrderID]).to eq(order_id)
  end
end
