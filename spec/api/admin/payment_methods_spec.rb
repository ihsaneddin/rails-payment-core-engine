require "rails_helper"

RSpec.describe "PaymentCore admin payment methods API", type: :request do
  include Rack::Test::Methods

  PAYMENT_METHOD_CLASSES = [
    "PaymentCore::PaymentMethods::Cash",
    "PaymentCore::PaymentMethods::BankTransfer",
    "PaymentCore::PaymentMethods::Fiuu"
  ].filter_map(&:safe_constantize).freeze

  def app
    PaymentCore::Grape::Base.draw
  end

  def json_body
    JSON.parse(last_response.body)
  end

  def collection_path_for(klass)
    "/admin/#{klass.method_type.to_s.pluralize}"
  end

  def member_path_for(record)
    "/admin/#{record.method_type.to_s.singularize}/#{record.id}"
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
      raise "Missing create payload for #{klass.name}"
    end
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
      raise "Missing existing-record factory for #{klass.name}"
    end
  end

  def member_processor_path_for(record, action)
    "#{member_path_for(record)}/#{action}"
  end

  let(:admin_user) { create(:user, email: "admin@example.com", name: "Admin") }
  let(:holder_user) { create(:user, email: "holder@example.com", name: "Holder") }
  let(:product_item) { create(:product_item, price: 10, name: "Product Item", sku: "item-1") }

  before(:all) do
    Order; LineItem; User; Product; PaymentPackageProductValue
    Product::Item; Product::Service; Product::PaymentPackage
  end

  def build_order(name: nil, item:, quantity: 1)
    create(:order, customer: holder_user, name: name, item: item, quantity: quantity)
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

  PAYMENT_METHOD_CLASSES.each do |payment_method_class|
    context payment_method_class.name do
      it "creates #{payment_method_class.method_type} via admin endpoint" do
        post collection_path_for(payment_method_class), create_payload_for(payment_method_class)

        expect(last_response.status).to eq(201)
        expect(json_body.fetch("data").fetch("holder_id")).to eq(holder_user.id)
        expect(json_body.fetch("data").fetch("method_type")).to eq(payment_method_class.method_type)
      end

      it "lists #{payment_method_class.method_type.pluralize} via admin endpoint" do
        record = existing_record_for(payment_method_class)

        get collection_path_for(payment_method_class)

        expect(last_response.status).to eq(200)
        expect(json_body.fetch("data").map { |row| row["id"] }).to include(record.id)
      end

      it "shows #{payment_method_class.method_type} via admin endpoint" do
        record = existing_record_for(payment_method_class)

        get member_path_for(record)

        expect(last_response.status).to eq(200)
        expect(json_body.fetch("data").fetch("id")).to eq(record.id)
      end

      it "updates #{payment_method_class.method_type} via admin endpoint" do
        record = existing_record_for(payment_method_class)

        put member_path_for(record), {
          display_name: "Updated #{payment_method_class.method_type.titleize}",
          holder_type: holder_user.class.name,
          holder_id: holder_user.id
        }

        expect(last_response.status).to eq(200)
        expect(json_body.fetch("data").fetch("display_name")).to eq("Updated #{payment_method_class.method_type.titleize}")
      end
    end
  end

  context "processor actions" do
    it "charges cash via admin endpoint" do
      cash_method = existing_record_for(PaymentCore::PaymentMethods::Cash)
      order = build_order(item: product_item, name: "admin-cash")

      post member_processor_path_for(cash_method, "charge"),
        payable_id: order.id,
        payable_type: order.class.name,
        currency: "MYR"

      expect(last_response.status).to be < 300
      expect(json_body.fetch("data").fetch("state")).to eq("succeeded")
    end

    it "charges bank transfer via admin endpoint" do
      bank_transfer_method = existing_record_for(PaymentCore::PaymentMethods::BankTransfer)
      order = build_order(item: product_item)
      order.update!(state: "waiting_payment")

      post member_processor_path_for(bank_transfer_method, "charge"),
        payable_id: order.id,
        payable_type: order.class.name,
        metadata: {}

      expect(last_response.status).to be < 300
      expect(json_body.fetch("data").fetch("payment_method_id")).to eq(bank_transfer_method.id)
    end

    it "requests bank transfer verification via admin endpoint" do
      bank_transfer_method = existing_record_for(PaymentCore::PaymentMethods::BankTransfer)
      order = build_order(item: product_item)
      order.update!(state: "waiting_payment")

      post member_processor_path_for(bank_transfer_method, "charge"),
        payable_id: order.id,
        payable_type: order.class.name,
        metadata: {}

      post member_processor_path_for(bank_transfer_method, "request_verification"),
        payable_id: order.id,
        payable_type: order.class.name,
        requested_by: "staff",
        proof: { file_url: "https://example.test/proof.png", note: "transfer" }

      expect(last_response.status).to eq(201)
    end

    it "verifies bank transfer via admin endpoint" do
      bank_transfer_method = existing_record_for(PaymentCore::PaymentMethods::BankTransfer)
      order = build_order(item: product_item)
      order.update!(state: "waiting_payment")

      post member_processor_path_for(bank_transfer_method, "charge"),
        payable_id: order.id,
        payable_type: order.class.name,
        metadata: {}

      post member_processor_path_for(bank_transfer_method, "request_verification"),
        payable_id: order.id,
        payable_type: order.class.name,
        requested_by: "staff",
        proof: { file_url: "https://example.test/proof.png", note: "transfer" }

      post member_processor_path_for(bank_transfer_method, "verify"),
        payable_id: order.id,
        payable_type: order.class.name,
        accepted: true,
        verified_by: "admin"

      expect(last_response.status).to be < 300
      expect(json_body.fetch("data").fetch("state")).to eq("succeeded")
    end

    it "builds fiuu redirect payload via admin endpoint" do
      fiuu_method = existing_record_for(PaymentCore::PaymentMethods::Fiuu)
      order = build_order(item: product_item)
      order.update!(state: "waiting_payment")

      post member_processor_path_for(fiuu_method, "charge"),
        payable_id: order.id,
        payable_type: order.class.name

      expect(last_response.status).to be < 300
      entry_payload = json_body.fetch("data")
      entry = PaymentCore::Entry.find(entry_payload.fetch("id"))
      method_data = entry.metadata.payment_method_data
      request_payload = method_data.gateway_request || {}
      order_id = request_payload[:orderid] || request_payload["orderid"]

      expect(method_data.redirect_url).to be_present
      expect(order_id).to eq(entry.number)
    end
  end
end
