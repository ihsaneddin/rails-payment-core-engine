class PaymentPackageSubscriber

  include ::Plugins::Models::Concerns::Eventable::SubscribesToEvents

  on_event :payment_package_purchased, handler: :process_payment_package_purchased, bus: :payment_package

  def process_payment_package_purchased event
    event.payload.dig(:object).process(
      event.payload.dig(:customer),
      quantity: event.payload.dig(:quantity),
      reference: event.payload.dig(:reference)
    )
  end

end