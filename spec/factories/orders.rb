FactoryBot.define do
  factory :order do
    type { "Order" }
    association :customer, factory: :user
    sequence(:name) { |n| "order-#{n}" }
    currency { "MYR" }

    transient do
      item { nil }
      quantity { 1 }
      use_item_data { true }
      line_items { [] }
    end

    after(:create) do |order, evaluator|
      if evaluator.item
        order.line_item_line_items.create!(
          item: evaluator.item,
          quantity: evaluator.quantity,
          use_item_data: evaluator.use_item_data
        )
      end

      Array(evaluator.line_items).each do |line_item_attrs|
        create(
          :line_item,
          {
            order: order,
            quantity: 1,
            use_item_data: true
          }.merge(line_item_attrs)
        )
      end
    end
  end
end
