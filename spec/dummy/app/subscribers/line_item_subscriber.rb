class LineItemSubscriber

  include ::Plugins::Models::Concerns::Eventable::SubscribesToEvents

  on_event :line_item_created, handler: :line_item_created, bus: :line_item
  on_event :line_item_updated, handler: :line_item_updated, bus: :line_item

  def line_item_created(event)
    event
  end

  def line_item_updated(event)
    event
  end

end