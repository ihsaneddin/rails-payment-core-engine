FactoryBot.define do
  factory :payment_method_availability_context,
          class: PaymentCore.config.payment_method.availability_context_class_constant do
    skip_create

    transient do
      regions { ["ID"] }
      currencies { ["MYR"] }
      use_cases { ["checkout"] }
      payables { [] }
    end

    initialize_with do
      PaymentCore.config.payment_method.availability_context_class_constant.new(
        regions: regions,
        currencies: currencies,
        use_cases: use_cases,
        payables: payables
      )
    end
  end
end
