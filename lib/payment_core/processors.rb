module PaymentCore
  module Processors
    # autoload :Base, "payment_core/processors/base"
    # autoload :Cash, "payment_core/processors/cash"

    module Object

      def self.included base
        base.include ::Plugins.decorators.method_annotations
        base.include ::Plugins.decorators.method_decorators
        base.extend ClassMethods
        base.include InstanceMethods
        base.inheritable_class_attribute :method_type
        base.attr_reader :payment_method, :context, :payer, :collective
        base.method_type = base.name.demodulize.underscore
        ::PaymentCore.config.payment_processor_registry.register(base.name)
      end

      module ClassMethods

        def inherited subclass
          super(subclass) if defined? super
          subclass.method_type = subclass.name.demodulize.underscore
          ::PaymentCore.config.payment_processor_registry.register(subclass.name)
        end

        def action method_name, &block
          single_action(method_name, &block)
        end

        def single_action method_name, &block
          annotate_method(method_name, single_action: true, &block)
        end

        def collective_action method_name, &block
          annotate_method("collective_#{method_name}".to_sym, collective_action: true, &block)
        end

        def webhook_action method_name, &block
          annotate_method("webhook_#{method_name}".to_sym, webhook_action: true, &block)
        end

        def action_access method_name, *accesses, prefix: nil
          action_access_method_names(method_name, prefix).each do |mname|
            annotate_method(mname, action_accesses: accesses.map(&:to_sym))
          end
        end

        def remove_action_access method_name, *accesses, prefix: nil
          action_access_method_names(method_name, prefix).each do |mname|
            annotations = annotations_for(mname)
            allowed = Array(annotations[:action_accesses]).compact.map(&:to_sym)
            next if allowed.empty?

            removals = accesses.map(&:to_sym)
            if removals.include?(:all) || removals.include?(:*)
              allowed = []
            else
              allowed -= removals
            end

            if allowed.empty?
              clear_annotation_keys_for(mname, :action_accesses)
            else
              annotate_method(mname, action_accesses: allowed)
            end
          end
        end

        def validate_payment_method method_name= nil, &block
          annotate_method("validate_#{method_name || SecureRandom.hex(5)}".to_sym, validate_payment_method: true, &block)
        end

        def params method_name, action_name=nil, type: nil, &block
          if action_name.nil?
            if method_name.to_s.end_with?("_params")
              action_name = method_name.to_s.delete_suffix("_params")
            end
          end
          raise "action_name is required" unless action_name
          if ["collective", "webhook"].include?(type.to_s)
            action_name = "#{type}_#{action_name}"
            method_name = "#{type}}_#{method_name}"
          end
          annotate_method(method_name, params: action_name.to_sym, &block)
        end

        def action_access_method_names(method_name, prefix)
          prefixes = Array(prefix)
          return [method_name.to_sym] if prefixes.empty?

          prefixes.flat_map do |pref|
            case pref
            when nil, :single, :action
              method_name.to_sym
            when :collective
              "collective_#{method_name}".to_sym
            when :webhook
              "webhook_#{method_name}".to_sym
            when :all
              [method_name.to_sym, "collective_#{method_name}".to_sym, "webhook_#{method_name}".to_sym]
            else
              "#{pref}_#{method_name}".to_sym
            end
          end.uniq
        end

      end

      module InstanceMethods
        def perform(action_name, *args)
          if action?(action_name)
            opts = args.extract_options!
            params = args[0] || opts.delete(:params)
            context = args[1] || opts.delete(:context)
            validate_payment_method(payment_method, params)
            send(action_name, params, context, **opts)
          else
            raise ::PaymentCore::Errors::UnknownProcessorActionError, "Invalid action name #{action_name}"
          end
        end

        def perform_with_access(action_name:, accesses: [], action_arguments: nil)
          validate_action_access!(action_name, accesses: accesses)
          args = Array(action_arguments).compact
          perform(action_name, *args)
        end

        def action?(method_name)
          single_action?(method_name) || collective_action?(method_name) || webhook_action?(method_name)
        end

        def single_action?(method_name)
          self.class.methods_annotated_with(:single_action, true).any?{|k| k == method_name.to_sym}
        end

        def collective_action?(method_name)
          self.class.methods_annotated_with(:collective_action, true).any?{|k| k == "#{method_name}".to_sym}
        end

        def webhook_action?(method_name)
          self.class.methods_annotated_with(:webhook_action, true).any?{|k| k == "#{method_name}".to_sym}
        end

        def params_for method_name, type: nil
          if ["collective", "webhook"].include?(type.to_s)
            method_name = "#{type}_#{method_name}"
          end
          mname = self.class.methods_annotated_with(:params, method_name.to_sym)[0]
          if mname
            send(mname)
          else
            []
          end
        end

        def presenter_of(action_name, entry, *args)
          opts = args.extract_options!
          cfg = entry.grape_api_resource_of(opts[:resource_context])
          cfg.presenter
        end

        private

        def payable_class payable_type
          payable_type.safe_constantize ||
          ::PaymentCore::Models::Decorators::Payable.registered_classes.find{|klass| klass.payable_api.type == payable_type } ||
          raise { ::ActiveRecord::RecordNotFound }
        end

        def validate_payment_method(payment_method, params)
          result = self.class.methods_annotated_with(:validate_payment_method, true).all? do |mname|
            arguments = [payment_method, params]
            valid = smart_send(mname, arguments)
            valid.nil? ? true : valid
          end
          unless result
            raise ::PaymentCore::Errors::InvalidPaymentMethodOnProcessor, "Invalid payment method object"
          end
        end

        def validate_action_access!(action_name, accesses:)
          access_list = Array(accesses).compact.map(&:to_sym)
          annotations = self.class.annotations_for(action_name.to_sym) || {}
          allowed = annotations[:action_accesses]

          if allowed.blank? && action_name.to_s.start_with?("collective_")
            base_name = action_name.to_s.delete_prefix("collective_").to_sym
            annotations = self.class.annotations_for(base_name) || {}
            allowed = annotations[:action_accesses]
          end

          if allowed.blank? && action_name.to_s.start_with?("webhook_")
            base_name = action_name.to_s.delete_prefix("webhook_").to_sym
            annotations = self.class.annotations_for(base_name) || {}
            allowed = annotations[:action_accesses]
          end
          allowed = Array(allowed).compact.map(&:to_sym)
          unless allowed.any? && (allowed & access_list).any?
            raise ::PaymentCore::Errors::ProcessorActionNotAllowed, "Processor action not allowed"
          end
        end

      end
    end

    require "payment_core/processors/base"
    require "payment_core/processors/cash"
    require "payment_core/processors/bank_transfer"
    require "payment_core/processors/fiuu"

  end
end
