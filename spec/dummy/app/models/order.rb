class Order < OrderCore::Order

  self.automatic_amounts_calculation= true

  payable do
    quantity 1
    total_item_amount :total_item_amount
    total_amount :total_amount
    # paid_amount do
    #   components = Array(payable_components).flatten
    #   payable_charge_entries.where(payable: components).succeeded.sum(:amount)
    # end
    currency "RM"
    components do
      line_items
    end
  end

  payable_entries_callback :after_save do |entry|
    if entry.charge? && entry.after_state_succeeded?
      complete!
    end
  end

  acts_as_ewallet_entry_reference

  # payment_method_availability :only_items_could_be_paid_by_package_payment do |payment_method, context|
  #   if payment_method.method_type == "payment_package"
  #     line_items.all?{|li| li.should_payment_method_be_available?(payment_method, context) }
  #   else
  #     true
  #   end
  # end

  def update_amounts
    self.update(total_item_amount: line_items.sum(:total_item_amount), total_amount: line_items.sum(:total_amount))
  end

  def complete!
    update!(state: "completed") unless state == "completed"
  end

  def after_completed?
    state.present? && saved_change_to_state? && state == 'completed'
  end

  publishes_event :completedd, on: :complete!, bus: :order

  payment_method_availability do |payment_method, context|
    line_items.any? do |line_item|
      line_item.should_payment_method_be_available?(payment_method, context)
    end
  end

end