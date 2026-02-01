module PaymentCore
  module Subscribers
    class EntrySubscriber

      include ::Plugins::Models::Concerns::Eventable::SubscribesToEvents

      on_event :created, handler: :created, bus: :entry
      on_event :updated, handler: :updated, bus: :entry
      on_event :saved, handler: :saved, bus: :entry
      on_event :destroyed, handler: :destroyed, bus: :entry

      def created(event)
        entry = event[:object]
        entry_event_callback(:created, entry)
      end

      def updated(event)
        entry = event[:object]
        entry_event_callback(:updated, entry)
      end

      def saved(event)
        entry = event[:object]
        entry_event_callback(:saved, entry)
      end

      def destroyed(event)
        entry = event[:object]
        entry_event_callback(:destroyed, entry)
      end

      protected

      def entry_event_callback(callback, entry)
        payable = entry&.payable
        return unless payable

        payable.payable_config.events.entry.send(callback, entry)
      end

    end
  end
end
