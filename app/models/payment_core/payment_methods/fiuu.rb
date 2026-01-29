module PaymentCore
  module PaymentMethods
    class Fiuu < ::PaymentCore::PaymentMethod

      self.method_type = "fiuu"

      DEFAULT_CHANNELS = [
        { code: "ALL", name: "All Channels", enabled: true }
      ].freeze

      class Metadata < ::PaymentCore::Attributes::PaymentMethods::Metadata

        class Channel < ::PaymentCore::Attributes::Base
          attribute :code, :string
          attribute :name, :string
          attribute :enabled, :boolean, default: true
        end

        attribute :flow, :string, default: "redirect"
        attribute :channels, Channel.to_array_type, default: []
        attribute :return_url, :string
        attribute :callback_url, :string
        attribute :notify_url, :string
        attribute :ipn_enabled, :boolean, default: false

        validates :flow, inclusion: { in: %w[redirect direct], message: :invalid }
        validates :channels, store_model: true

        def direct_flow?
          flow.to_s == "direct"
        end
      end

      define_metadata_class(Metadata)

      intent_driven
      credentials fields: {
        :merchant_id => true, :secret_key => true, :verify_key => true
      }

      entry_callback :after_create do |entry|
        delay = ::PaymentCore.config.payment_method.webhook_sla_seconds.to_i
        ::PaymentCore::EntryWorker.perform_at(Time.current + delay, entry.id, "check_status")
      end

      after_initialize do
        next unless new_record?

        existing = Array(metadata.channels)
        existing_map = existing.index_by { |chan| chan&.code.to_s }
        defaults = DEFAULT_CHANNELS.map do |attrs|
          Metadata::Channel.new(attrs)
        end
        if existing.empty?
          metadata.channels = defaults
        else
          defaults_map = defaults.index_by { |chan| chan&.code.to_s }
          merged = existing.map do |chan|
            default = defaults_map[chan&.code.to_s]
            next chan unless default

            default_attrs = default.respond_to?(:attributes) ? default.attributes : default.to_h
            existing_attrs = chan.respond_to?(:attributes) ? chan.attributes : chan.to_h
            Metadata::Channel.new(default_attrs.merge(existing_attrs))
          end
          metadata.channels = merged
        end
      end

      def redirect_flow?
        metadata.flow.to_s == "redirect"
      end

      def direct_flow?
        metadata.flow.to_s == "direct"
      end

      def enabled_channels
        Array(metadata.channels).select { |chan| chan&.enabled != false }
      end

      def enabled_channel_codes
        enabled_channels.map { |chan| chan.code }.compact
      end

      def gateway
        ::PaymentCore::Gateways::Fiuu.new(
          merchant_id: metadata_merchant_id,
          secret_key: metadata_secret_key
        )
      end

    end
  end
end
