FactoryBot.define do
  factory :cash_payment_method, class: "PaymentCore::PaymentMethods::Cash" do
    sequence(:display_name) { |n| "Cash #{n}" }
    active { true }
    always_available { true }
    association :holder, factory: :user
  end

  factory :bank_transfer_payment_method, class: "PaymentCore::PaymentMethods::BankTransfer" do
    sequence(:display_name) { |n| "Bank Transfer #{n}" }
    active { true }
    always_available { true }
    association :holder, factory: :user
    bank_name { "Bank Example" }
    bank_code { "BANK-EX" }
    bank_account_name { "Test Account" }
    bank_account_number { "1234567890" }
  end

  factory :fiuu_payment_method, class: "PaymentCore::PaymentMethods::Fiuu" do
    sequence(:display_name) { |n| "Fiuu #{n}" }
    active { true }
    always_available { true }
    association :holder, factory: :user
    metadata_merchant_id { "merchant-1" }
    metadata_secret_key { "secret-1" }
    metadata_verify_key { "verify-1" }
  end
end
