# desc "Explaining what the task does"
# task :payment_core do
#   # Task goes here
# end
#

namespace :payment_core do

  desc "Grape api routes"
  task grape_routes: :environment do
    klass = PaymentCore.config.grape_api.base_endpoint_class.constantize rescue nil
    if klass
      klass.routes.each do |api|
        method = api.request_method.ljust(10) if api.request_method
        path = api.path.gsub ":version", api.version if api.version
        path ||= api.path
        puts "    #{method} #{path}"
      end
    else
      puts "No base api class defined"
    end
  end

  desc "Test"
  task :test => :environment do

    if Rails.env.development?
      Rails.application.eager_load!

      ["users",
        'ewallet_wallets',
        'ewallet_accounts',
        'ewallet_entries',
        'ewallet_amounts',
        'ewallet_issuers',
        'ewallet_currencies',
        'payment_core_payment_methods',
        'payment_core_entries',
        'order_core_orders',
        'order_core_line_items',
        'products',
        'payment_package_product_values'
    ].each do |table_name|
      ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table_name} RESTART IDENTITY CASCADE")
    end
      default_payment_methods_builder = ::PaymentCore.config.payment_method.default_payment_methods_builder
      if default_payment_methods_builder && default_payment_methods_builder.is_a?(Proc)
        if ::PaymentCore::PaymentMethod.where.not(id: nil).empty?
          ::PaymentCore::PaymentMethod.instance_exec(&default_payment_methods_builder)
        end
      end

      puts "# Create a customer\n"
      customer = User.create(email: "user@mail.com", name: "user")
      puts "# Created a customer with id #{customer.id}\n"
      puts "# Create Product item"
      product_item = Product::Item.create(price: 10, name: "Product Item #1", sku: "1")
      puts "# Create Product service"
      product_service = Product::Service.create(price: 15, name: "Product Service #1", sku: "2")

      puts "# Create Product top up for ewallet"
      product_top_up_wallet = Product::PaymentPackage.create(
        price: 45, name: "Ewallet Top Up", sku: "3",
        amount_per_quantity: 50,
        allow_purchase_on_any_item: true,
        will_be_expired: false, currency: "Ringgit Malaysian",
        custom_value: false,
      )

      puts "# Create Product top up for service package ewallet"
      product_top_up_service_package = Product::PaymentPackage.create(
        price: 20, name: "Service Package Top Up", sku: "4",
        amount_per_quantity: 100,
        allow_purchase_on_any_item: false,
        disallow_purchase_on_item_ids: [product_top_up_wallet.id, product_item.id],
        will_be_expired: false, currency: "Service Package",
        product_values_attributes: [
          { product_id: product_service.id, value: 10 }
        ]
      )

      puts "# Create customer order to purchase product item and top up of service package"
      order = Order.create(customer: customer)
      line_item_item =order.line_item_line_items.create(item: product_item, quantity: 1, use_item_data: true)
      line_item_topup_ewallet =order.line_item_line_items.create(item: product_top_up_wallet, quantity: 1, use_item_data: true)
      line_item_service_package =order.line_item_line_items.create(item: product_top_up_service_package, quantity: 1, use_item_data: true)

      context = PaymentCore.config.payment_method.availability_context_class_constant.new(regions: ["ID"], currencies: ["RM"], use_cases: ["checkout"], payables: [order])

      pms = customer.available_payment_methods(context: context)

      cash = pms.find{|pm| pm.cash? }

      order.reload
      puts "# Pay the order using cash"
      wrapper = cash.processor(payer: customer, context: context).charge(
        amount: order.total_amount, payable: order, currency: "RM",
        metadata: {
          payment_method_data: {}
        }
      )
      puts "The order state should be 'completed'"
      if order.reload.state != "completed"
        raise "Test failed"
      end

      expected_balance = product_top_up_wallet.amount_per_quantity * line_item_topup_ewallet.quantity
      puts "# Customer ewallet service package should be #{expected_balance}"
      ewallet_account = customer.current_ewallet.get_accounts_of(product_top_up_wallet.get_or_create_ewallet_currency).first
      puts "# Customer ewallet service package balance : #{ewallet_account.balance}"

      if expected_balance != ewallet_account.balance
        raise "Test failed"
      end

      expected_balance = product_top_up_service_package.amount_per_quantity * line_item_service_package.quantity
      puts "# Customer ewallet service package should be #{expected_balance}"
      ewallet_account = customer.current_ewallet.get_accounts_of(product_top_up_service_package.get_or_create_ewallet_currency).first
      puts "# Customer ewallet service package balance : #{ewallet_account.balance}"
      if expected_balance != ewallet_account.balance
        raise "Test failed"
      end

      puts "# Create customer order to purchase product item and service item"
      order = Order.create(customer: customer)
      line_item = order.line_item_line_items.create(item: product_item, quantity: 1, use_item_data: true)
      line_item2 = order.line_item_line_items.create(item: product_service, quantity: 1, use_item_data: true)

      pms = customer.available_payment_methods()
      sp = pms.find{|pm| pm.payment_package? && pm.package.custom_value  }

      order.reload
      puts "# Pay the order using customer ewallet service package"
      entry = sp.processor.charge(
        amount: order.total_amount,
        payable: order,
        currency: "RM",
        metadata: {
          payment_method_data: {}
        }
      )
      puts "# Should be failed because a product item is on the line items"

      unless entry.errors.any?
        raise "Test failed"
      end

      puts "# Create customer order to purchase service package item"
      order = Order.create(customer: customer, name: "anjing")
      line_item = order.line_item_line_items.create(item: product_service, quantity: 1, use_item_data: true)

      pms = customer.available_payment_methods()

      sp = pms.find{|pm| pm.payment_package? && pm.package.custom_value }

      previous_balance = ewallet_account.balance
      order.reload
      puts "# Total order amount #{order.reload.payable_total_amount.to_s}"
      puts "# Total balance #{sp.balance.to_s}"
      puts "# Pay the order using customer ewallet service package"
      entry = sp.processor.charge(
        amount: order.total_amount,
        payable: order,
        currency: "RM",
        metadata: {
          payment_method_data: {}
        }
      )

      puts "The order state should be 'completed'"
      if order.reload.state != "completed"
        raise "Test failed"
      end
      expected_balance = previous_balance - (line_item.quantity * product_top_up_service_package.get_value_of_product(product_service))

      puts "# Customer ewallet service package should be #{expected_balance}"
      ewallet_account = customer.current_ewallet.get_accounts_of(product_top_up_service_package.get_or_create_ewallet_currency).first
      puts "# Customer ewallet service package balance : #{ewallet_account.balance}"
      if expected_balance != ewallet_account.balance
        raise "Test failed"
      end

      puts "Test refund charge"
      charge = PaymentCore::Entries::Charge.order("updated_at desc").first
      puts "Charge ID: #{charge.id} for refund"
      puts "Payment method ID: #{charge.payment_method_id}"
      # puts "Charge ##{charge.id} with payment_method_amount #{charge.payment_method_amount} will be refunded"
      # prev_balance = charge.payment_method.balance
      # puts "Initial payment_method balance #{charge.payment_method.balance}"
      # refund = PaymentCore::Entries::Refund.new(use_payable_data: true, payable: charge)
      # refund.save
      # refund.success!
      # puts "After refund payment_method balance #{charge.payment_method.balance}"
      # if prev_balance + refund.payment_method_amount != charge.payment_method.balance
      #   raise "Test failed"
      # end

      puts "# Create customer order to purchase product item to be paid by Cash for api testing scenario 1"
      order = Order.create(customer: customer)
      line_item = order.line_item_line_items.create(item: product_item, quantity: 1, use_item_data: true)
      puts "# Order ID: #{order.id}"

      puts "# Create customer order to purchase product item and service item to be paid by Service Package for api testing scenario 2"
      order = Order.create(customer: customer)
      line_item = order.line_item_line_items.create(item: product_item, quantity: 1, use_item_data: true)
      line_item2 = order.line_item_line_items.create(item: product_service, quantity: 1, use_item_data: true)
      puts "# Order ID: #{order.id}"

      puts "# Create customer order to purchase and service item to be paid by Service Package for api testing scenario 3"
      order = Order.create(customer: customer)
      line_item = order.line_item_line_items.create(item: product_service, quantity: 1, use_item_data: true)
      puts "# Order ID: #{order.id}"

      puts "# Create customer order to purchase and service item to be paid by Service Package for api testing scenario 4"
      order = Order.create(customer: customer)
      line_item = order.line_item_line_items.create(item: product_service, quantity: 20, use_item_data: true)
      puts "# Order ID: #{order.id}"

      puts "# Create customer order to purchase and service item to be paid by multiple payment packages for api testing scenario 5"
      order = Order.create(customer: customer)
      line_item = order.line_item_line_items.create(item: product_service, quantity: 1, use_item_data: true)
      line_item = order.line_item_line_items.create(item: product_item, quantity: 1, use_item_data: true)
      puts "# Order ID: #{order.id}"

      puts "Current Balance"
      puts "Service Package Balance : #{customer.current_ewallet.get_accounts_of(product_top_up_service_package.get_or_create_ewallet_currency).first.balance}"
      puts "Ewallet Balance : #{customer.current_ewallet.get_accounts_of(product_top_up_wallet.get_or_create_ewallet_currency).first.balance}"

    end

  end
end