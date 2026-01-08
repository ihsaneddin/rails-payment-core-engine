module PaymentCore
  module Processors
    autoload :Base, "payment_core/processors/base"
    autoload :Cash, "payment_core/processors/cash"

    module Object

      def self.included base
        base.include ::Plugins.decorators.method_annotations
        base.include ::Plugins.decorators.method_decorators
        base.extend ClassMethods
        base.include InstanceMethods
        base.inheritable_class_attribute :method_type
        base.attr_reader :payment_method, :context, :payer, :collective
        base.method_type = base.name.demodulize.underscore
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
          annotate_method("webhook_#{method_name}",to_sym, webhook_action: true, &block)
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

      end

      module InstanceMethods
        def perform(action_name, *args)
          if action?(action_name)
            opts = args.extract_options!
            params = args[0] || opts.delete(:params)
            context = args[1] || opts.delete(:context)
            send(action_name, params, context, **opts)
          else
            raise ::PaymentCore::Errors::UnknownProcessorActionError, "Invalid action name #{action_name}"
          end
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

        def collective_action?(method_name)
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

        def payable_class payable_type
          payable_type.safe_constantize ||
          ::PaymentCore.decorators.payable.payable_classes.find{|klass| klass.payable_api.type == payable_type } ||
          raise { ::ActiveRecord::RecordNotFound }
        end

      end
    end

  end
end