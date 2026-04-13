FactoryBot.define do
  factory :product_item, class: "Product::Item" do
    sequence(:name) { |n| "Product Item #{n}" }
    sequence(:sku) { |n| "item-#{n}" }
    price { 10 }
    unit_quantity { 1 }
  end

  factory :product_service, class: "Product::Service" do
    sequence(:name) { |n| "Product Service #{n}" }
    sequence(:sku) { |n| "service-#{n}" }
    price { 15 }
    unit_quantity { 1 }
  end

  factory :product_payment_package, class: "Product::PaymentPackage" do
    sequence(:name) { |n| "Payment Package #{n}" }
    sequence(:sku) { |n| "package-#{n}" }
    price { 20 }
    amount_per_quantity { 100 }
    item_cost_per_quantity { 1 }
    allow_purchase_on_any_item { false }
    will_be_expired { false }
    currency { "Service Package" }
    custom_value { true }
    disallow_purchase_on_item_ids { [] }

    transient do
      product_values { [] }
    end

    after(:build) do |payment_package, evaluator|
      if evaluator.product_values.present?
        payment_package.product_values_attributes = evaluator.product_values
      end
    end

    trait :wallet_top_up do
      price { 45 }
      amount_per_quantity { 50 }
      allow_purchase_on_any_item { true }
      currency { "Ringgit Malaysian" }
      custom_value { false }
    end
  end
end
