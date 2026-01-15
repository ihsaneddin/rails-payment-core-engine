require "rails_helper"

RSpec.describe PaymentCore::Processors::BankTransfer do

  let(:payer) { User.create!(email: "user@example.com", name: "User") }
  let(:product_item) { Product::Item.create!(price: 100, name: "Test Item", sku: "item-1") }
  let(:payable) do
    order = Order.create!(customer: payer, name: "anjing")
    order.line_item_line_items.create!(item: product_item, quantity: 1, use_item_data: true)
    order.reload
  end
  let(:payment_method) do
    PaymentCore::PaymentMethods::BankTransfer.create!(
      display_name: "Bank Transfer",
      bank_name: "Bank Example",
      bank_code: "BANK-EX",
      bank_account_name: "Test Account",
      bank_account_number: "1234567890",
      default_currency: "RM",
      active: true,
      always_available: true
    )
  end
  let(:context) do
    PaymentCore.config.payment_method.availability_context_class_constant.new(
      regions: ["ID"],
      currencies: ["RM"],
      use_cases: ["checkout"],
      payables: [payable]
    )
  end
  let(:processor) { payment_method.processor(payer: payer, context: context) }

  it "returns an error when intent is required and missing" do
    entry = processor.charge(payable: payable, metadata: {})

    expect(entry).to be_a(PaymentCore::Entries::Charges::BankTransfer)
    expect(entry.errors[:payment_intent_id]).to be_present
    expect(entry).not_to be_persisted
  end

  it "applies payment method defaults into entry method_data" do
    payable.update!(state: "waiting_payment")
    payable.reload

    entry = processor.charge(
      payable: payable,
      metadata: {
        proofs: [{ file_url: "https://example.test/proof-seed.png", note: "seed" }],
        payment_method_data_attributes: {
          sender_bank: "Sender Bank"
        }
      }
    )

    method_data = entry.metadata.payment_method_data
    expect(method_data).to be_present
    expect(method_data.recipient_account_number).to eq(payment_method.bank_account_number)
    expect(method_data.recipient_account_name).to eq(payment_method.bank_account_name)
    expect(method_data.recipient_bank).to eq(payment_method.bank_name)
    expect(method_data.recipient_bank_code).to eq(payment_method.bank_code)
    expect(method_data.currency).to eq(payment_method.default_currency)
    expect(method_data.sender_bank).to eq("Sender Bank")
  end

  it "manages proofs via metadata helpers" do
    payable.update!(state: "waiting_payment")
    payable.reload

    entry = processor.charge(
      payable: payable,
      metadata: {
        proofs: [{ file_url: "https://example.test/proof-seed.png", note: "seed" }]
      }
    )

    proof = entry.metadata.add_proof(file_url: "https://example.test/proof-1.png", note: "first")
    expect(proof).to be_a(PaymentCore::Models::Decorators::Entry::RequiresProof::Proof)
    expect(entry.metadata.proofs.length).to eq(2)

    entry.metadata.update_proof(1, note: "updated")
    expect(entry.metadata.proofs.last.note).to eq("updated")

    removed = entry.metadata.delete_proof(1)
    expect(removed.file_url).to eq("https://example.test/proof-1.png")
    expect(entry.metadata.proofs.length).to eq(1)
  end

  context "when verification is required" do
    it "adds proof and transitions to verification_pending" do
      payable.update!(state: "waiting_payment")
      payable.reload

      entry = processor.charge(
        payable: payable,
        metadata: {
          proofs: [{ file_url: "https://example.test/proof-seed.png", note: "seed" }]
        }
      )

      result = processor.request_verification(
        payable_id: payable.id,
        payable_type: payable.class.name,
        requested_by: "staff",
        proof: { file_url: "https://example.test/proof.png", note: "transfer" }
      )
      expect(result).to eq(entry)
      expect(result.state).to eq("verification_pending")
      expect(result.metadata.proofs.length).to eq(2)
      expect(result.metadata.proofs.last.file_url).to eq("https://example.test/proof.png")
      expect(result.metadata.verification_attempts.length).to eq(1)
    end

    it "accepts verification and transitions to succeeded" do
      payable.update!(state: "waiting_payment")
      payable.reload

      entry = processor.charge(
        payable: payable,
        metadata: {
          proofs: [{ file_url: "https://example.test/proof-seed.png", note: "seed" }]
        }
      )

      processor.request_verification(
        payable_id: payable.id,
        payable_type: payable.class.name,
        requested_by: "staff",
        proof: { file_url: "https://example.test/proof.png", note: "transfer" }
      )

      result = processor.verify(
        payable_id: payable.id,
        payable_type: payable.class.name,
        accepted: true,
        verified_by: "admin"
      )

      expect(result).to eq(entry)
      expect(result).to be_succeeded
      expect(result.metadata.verification_attempts.last.accepted).to be(true)
      expect(result.metadata.verification_attempts.last.verified_by).to eq("admin")
    end

    it "rejects verification and transitions to verification_failed" do
      payable.update!(state: "waiting_payment")
      payable.reload

      entry = processor.charge(
        payable: payable,
        metadata: {
          proofs: [{ file_url: "https://example.test/proof-seed.png", note: "seed" }]
        }
      )

      processor.request_verification(
        payable_id: payable.id,
        payable_type: payable.class.name,
        requested_by: "staff",
        proof: { file_url: "https://example.test/proof.png", note: "transfer" }
      )

      result = processor.verify(
        payable_id: payable.id,
        payable_type: payable.class.name,
        accepted: false,
        verified_by: "admin"
      )

      expect(result).to eq(entry)
      expect(result.state).to eq("verification_failed")
      expect(result.metadata.verification_attempts.last.accepted).to be(false)
      expect(result.metadata.verification_attempts.last.verified_by).to eq("admin")
    end
  end
end
