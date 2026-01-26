module PaymentCore
  module Configuration
    module PaymentMethod

      mattr_accessor :metadata_base_class
      mattr_accessor :availability_rules_class
      mattr_accessor :availability_context_class
      mattr_accessor :availabilty_matcher_class
      mattr_accessor :default_payment_methods_builder
      mattr_accessor :default_context_builder
      mattr_accessor :processor_action_params
      mattr_accessor :processor_webhook_action_params
      mattr_accessor :credentials_encryption_key

      @@metadata_base_class = "PaymentCore::Attributes::PaymentMethods::Metadata"
      @@availability_rules_class = "PaymentCore::Attributes::PaymentMethods::AvailabilityRules"
      @@availability_context_class = "PaymentCore::Services::PaymentMethods::AvailabilityContext"
      @@availabilty_matcher_class = "PaymentCore::Services::PaymentMethods::AvailabilityMatcher"
      @@default_context_builder = proc { |opts = {}|
        opts = {regions: ["ID", "MY", currencies: ["IDR", "RM"]]}.merge(opts)
        ::PaymentCore.config.payment_method.availability_context_class_constant.new(**opts)
      }
      @@processor_action_params = proc {
        {}
      }
      @@processor_webhook_action_params = proc {
        {}
      }
      @@credentials_encryption_key = proc { Rails.application.credentials.secret_key_base }
      @@default_payment_methods_builder = proc {
        if PaymentCore::PaymentMethod.where.not(id: nil).empty?
          PaymentCore::PaymentMethods::Cash.create(display_name: "Cash", active: true, always_available: true)
        end
      }

      def self.metadata_base_class_constant
        @@metadata_base_class.constantize
      end

      def self.availability_rules_class_constant
        @@availability_rules_class.constantize
      end

      def self.availability_context_class_constant
        @@availability_context_class.constantize
      end

      def self.availabilty_matcher_class_constant
        @@availabilty_matcher_class.constantize
      end

      def self.default_context_builder &block
        if block_given?
          @@default_context_builder = block
        else
          @@default_context_builder
        end
      end

      def self.default_payment_methods_builder &block
        if block_given?
          @@default_payment_methods_builder = block
        else
          @@default_payment_methods_builder
        end
      end

      def self.processor_action_params &block
        if block_given?
          @@processor_action_params = block
        else
          @@processor_action_params
        end
      end

      def self.processor_webhook_action_params &block
        if block_given?
          @@processor_webhook_action_params = block
        else
          @@processor_webhook_action_params
        end
      end

      def self.credentials_encryption_key(value = nil, &block)
        if block_given?
          @@credentials_encryption_key = block
        elsif !value.nil?
          @@credentials_encryption_key = value
        else
          @@credentials_encryption_key
        end
      end

      def self.setup &block
        raise "Block is not provided" unless block_given?
        block.arity.zero? ? instance_eval(&block) : yield(self)
      end

    end
  end
end
