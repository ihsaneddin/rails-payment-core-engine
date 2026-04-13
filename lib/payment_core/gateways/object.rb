module PaymentCore
  module Gateways
    module Object

      extend ::Plugins::Decorators::ConfigBuilder
      include ::Plugins.decorators.registered

      def self.included(base)
        base.extend ClassMethods
        default_opts = ::PaymentCore::Gateways::Object.default_options
        ::PaymentCore::Gateways::Object.plugins_config.setup(
          base,
          "config",
          {},
          default_opts,
          method_prefix: "config"
          )
        base.inheritable_class_attribute :gateway_type
        base.gateway_type = base.name.demodulize.underscore
        ::PaymentCore::Gateways::Object << base
      end

      def self.default_options
        {
          base_url: nil,
          timeout: nil,
          open_timeout: nil,
          entry_resolver: proc { |*_args| nil },
          webhook_payload_filter: proc { |_params| {} },
          webhook_response: proc { |_opts = {}| { status: "ok" } },
          signature_fields: nil,
          signature_builder: nil
        }
      end

      def normalize_webhook_payload(request:, params:)
        return {} unless respond_to?(:config_webhook_payload_filter)
        config_webhook_payload_filter(params) || {}
      end

      def response(entry:, params:, request:)
        yield if block_given?
        config.webhook_response({ entry: entry, params: params, request: request }) || { status: "ok" }
      end

      module ClassMethods

        def configure(**opts, &block)
          default_opts = ::PaymentCore::Gateways::Object.default_options
          ::PaymentCore::Gateways::Object.plugins_config.setup(
            self,
            "config",
            opts,
            default_opts,
            method_prefix: "config",
            &block
          )
        end

        def add_configuration(key, default_value = nil)
          config.add(key.to_sym, default_value)
          method_prefix = "config"
          define_method("#{method_prefix}_#{key}") do |*args|
            self.send(:config).get(key, *args)
          end
          define_inheritable_singleton_method("#{method_prefix}_#{key}") do |*args|
            self.send(:config).get(key, *args)
          end
        end

        def add_config(key, default_value = nil)
          add_configuration(key.to_sym, default_value)
        end

      end

    end
  end
end
