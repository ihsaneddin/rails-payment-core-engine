class LineItem < OrderCore::LineItem
  payable do
    quantity :quantity
    total_item_amount :total_item_amount
    total_amount :total_amount
    currency do
      order&.currency
    end
    payment_method_item_amount do |payment_method|
      if payment_method.payment_package? && payment_method.package.custom_value
        item.payment_package_value(payment_method.package)
      else
        payable_total_item_amount.to_d / quantity
      end
    end
    payment_method_total_amount do |payment_method|
      payable_quantity * payable_payment_method_item_amount(payment_method)
    end
    to_payment_method_amount do |payment_method, amount|
      payable_payment_method_total_amount(payment_method) * (amount.to_d / payable_total_amount)
    end
    from_payment_method_amount do |payment_method, payment_method_amount|
      payable_total_amount * (payment_method_amount.to_d / payable_payment_method_total_amount(payment_method))
    end
  end

  acts_as_ewallet_entry_reference

  # payment_method_availability :only_item_could_be_paid_by_package_payment do |payment_method, context|
  #   item.should_payment_method_be_available?(payment_method, context)
  # end

  define_singleton_method :order_callback do |callback_name, method_name = nil, opts = {}, &block|
    opts = { source: :line_items, if: true, exclusive: false }.merge(opts)
    callback_for(Order, callback_name, method_name, opts, &block)
  end

  order_callback :after_save do |order|
    if order.after_completed? && (item.instance_of? Product::PaymentPackage)
      publish_event('purchased', bus: :payment_package, prefix: 'payment_package', object: item,
                                 customer: order.customer, quantity: quantity, reference: self)
    end
  end

  before_save do
    self.total_amount = total_item_amount - total_discount_amount + total_tax_amount
  end

  after_create do
    publish_event(:created, bus: :line_item, **{ object: self, order: order })
  end

  after_update do
    publish_event(:updated, bus: :line_item, **{ object: self, order: order })
  end

  payment_method_availability do |payment_method, context|
    if item && item.payable?
      item.should_payment_method_be_available?(payment_method, context)
    else
      true
    end
  end

end
