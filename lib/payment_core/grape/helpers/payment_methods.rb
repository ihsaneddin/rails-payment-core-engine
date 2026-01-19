module PaymentCore
  module Grape
    module Helpers
      module PaymentMethods

        def self.included(base)
          base.helpers HelperMethods
          base.rescue_from ::PaymentCore::Errors::UnknownProcessorActionError, ::PaymentCore::Errors::UnknownProcessorError do |e|
            standard_not_found_error(message: e.message)
          end
          base.rescue_from ::PaymentCore::Errors::ProcessorActionNotAllowed do |_e|
            standard_permission_denied_error
          end
        end

        module HelperMethods

          def payment_method_class
            unless @payment_method_class
              @payment_method_class = instance_exec(class_context.payment_method_type, &class_context.payment_method_class_finder)
              raise ::ActiveRecord::RecordNotFound unless @payment_method_class
            end
            @payment_method_class
          end

          def processor_action?
            route.options[:processor_action]
          end

          def processor_collective_action?
            route.options[:collective_action]
          end

          def payment_method_type
            params[:method_type]
          end

          def processor_action_name
            prefix = processor_collective_action? ? "collective" : nil
            @processor_action_name ||= [prefix, params[:processor_action]].compact.join("_")
          end

          def processor_action_arguments
            permitted = processor.params_for(processor_action_name.to_sym)
            permitted = posts.permit(*permitted)
            opts = ::PaymentCore.config.payment_method.processor_action_params
            args = [permitted, given_context]

            if opts.is_a?(Proc)
              opts = instance_exec(&opts)
            end
            opts[:collective] = processor_collective_action?
            args << opts
            args
          end

          def processor_action_accesses
            class_context.try(:processor_action_accesses) || []
          end

          def processor
            return @processor if @processor
            if processor_collective_action?
              payment_methods = records.where(method_type: payment_method_type)
              unless params[:payment_method_ids].blank?
                payment_methods = payment_methods.where(id: params[:payment_method_ids])
              end
              @processor ||= ::PaymentCore.config.payment_processor_registry
                .resolve(payment_method_type).new(payment_methods, **{ context: given_context, payer: current_holder, collective: true })
            else
              @processor ||=
                record.processor(context: given_context, payer: current_holder)
            end
            unless @processor.single_action?(processor_action_name) || @processor.collective_action?(processor_action_name)
              standard_not_found_error(message: "Not found")
            end
            @processor
          rescue => e
            standard_not_found_error(message: e.message)
          end

          def given_context
            return @context if @context
            context_builder = class_context.try(:given_context)
            @context = context_builder.is_a?(Proc) ? instance_exec(&context_builder) : context_builder
          end

          def payables(payable_params = {})
            payable_params ||= {}
            @payables ||= payable_params.inject([]) do |arr, (payable_type, ids)|
              arr + payable_class(payable_type).payable_api.finders(ids)
            end
          rescue
            raise { ::ActiveRecord::RecordNotFound }
          end

          def payable_class(payable_type)
            payable_type.safe_constantize ||
            ::PaymentCore::Models::Decorators::Payable.registered_classes.find{|klass| klass.payable_api.type == payable_type } ||
            raise { ::ActiveRecord::RecordNotFound }
          end

        end

      end

    end
  end
end
