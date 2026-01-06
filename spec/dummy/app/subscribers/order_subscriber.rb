class OrderSubscriber

  include ::Plugins::Models::Concerns::Eventable::SubscribesToEvents

  on_event :order_completed, handler: :process_completed_order, bus: :order

  def process_completed_order(event)
    event
  end

end