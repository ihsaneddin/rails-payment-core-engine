FactoryBot.define do
  factory :line_item do
    association :order
    association :item, factory: :product_item
    quantity { 1 }
    use_item_data { true }
  end
end
