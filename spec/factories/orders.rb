FactoryBot.define do
  factory :order do
    association :customer, factory: :user
    sequence(:name) { |n| "order-#{n}" }
    currency { "MYR" }

    transient do
      item { nil }
      quantity { 1 }
      use_item_data { true }
    end

    after(:create) do |order, evaluator|
      next unless evaluator.item

      order.line_item_line_items.create!(
        item: evaluator.item,
        quantity: evaluator.quantity,
        use_item_data: evaluator.use_item_data
      )
    end
  end
end
