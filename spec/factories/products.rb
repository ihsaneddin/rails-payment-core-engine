FactoryBot.define do
  factory :product_item, class: "Product::Item" do
    sequence(:name) { |n| "Product Item #{n}" }
    sequence(:sku) { |n| "item-#{n}" }
    price { 10 }
    unit_quantity { 1 }
  end
end
