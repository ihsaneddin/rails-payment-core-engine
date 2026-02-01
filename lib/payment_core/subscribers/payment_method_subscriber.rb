module PaymentCore
  module Subscribers
    class PaymentMethodSubscriber

      include ::Plugins::Models::Concerns::Eventable::SubscribesToEvents

      on_event :created, handler: :created, bus: :payment_method
      on_event :updated, handler: :updated, bus: :payment_method
      on_event :saved, handler: :saved, bus: :payment_method
      on_event :destroyed, handler: :destroyed, bus: :payment_method

      def created(event)
        payment_method = event[:object]
        payment_method_event_callback(:created, payment_method)
      end

      def updated(event)
        payment_method = event[:object]
        payment_method_event_callback(:updated, payment_method)
      end

      def saved(event)
        payment_method = event[:object]
        payment_method_event_callback(:saved, payment_method)
      end

      def destroyed(event)
        payment_method = event[:object]
        payment_method_event_callback(:destroyed, payment_method)
      end

      protected

      def payment_method_event_callback(callback, payment_method)
        holder = payment_method&.holder
        return unless holder

        holder.payment_method_holder_config.events.payment_method.send(callback, payment_method)
      end

    end
  end
end
