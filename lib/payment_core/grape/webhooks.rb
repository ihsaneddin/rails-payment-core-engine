module PaymentCore
  module Grape
    class Webhooks < ::PaymentCore::Grape::Base

      skip_authentication!
      route_setting :skip_authorization, true

      inheritable_class_attribute :processor_webhook_action_accesses, :given_context
      self.processor_webhook_action_accesses = [:public_webhook]
      self.given_context = lambda do
        builder = ::PaymentCore.config.payment_method.default_context_builder
        context_opts = {}
        builder.is_a?(Proc) ? instance_exec(context_opts, &builder) : builder
      end

      rescue_from ::ActiveRecord::RecordNotFound do |e|
        standard_not_found_error(message: "Not found")
      end

      helpers do

        def entry
          @entry ||= find_entry_from_webhook(params) || raise(::ActiveRecord::RecordNotFound)
        end

        def payment_method
          @payment_method ||= entry.payment_method
        end

        def gateway
          @gateway ||= payment_method.gateway
        end

        def processor
          @processor ||= entry.payment_method.processor(payer: entry.payer)
        end

        def processor_action_name
          :webhook_capture
        end

        def given_context
          return @context if @context
          context_builder = class_context.try(:given_context)
          @context = context_builder.is_a?(Proc) ? instance_exec(&context_builder) : context_builder
        end

        def webhook_action_arguments
          permitted = processor.params_for(:capture, type: :webhook)
          permitted = posts.permit(*permitted)
          permitted[:entry] = entry
          permitted[:webhook_payload] = gateway.normalize_webhook_payload(request: request, params: params)
          args = [permitted, given_context]
          args << webhook_action_options
          args
        end

        def webhook_action_options
          opts = ::PaymentCore.config.payment_method.processor_webhook_action_params
          opts = instance_exec(&opts) if opts.is_a?(Proc)
          opts || {}
        end

        def find_entry_from_webhook(params)
          gateway_class = resolve_gateway_class
          return nil unless gateway_class

          gateway_class.config_entry_resolver(params)
        end

        def resolve_gateway_class
          type = params[:gateway_type].to_s
          ::PaymentCore::Gateways::Object.registered_classes.find do |klass|
            klass.gateway_type.to_s == type
          end
        end

      end
      class << self
        def draw &block
          klass = duplicate(self)
          klass.class_exec(&block) if block_given?
          klass.resources "webhook/:gateway_type" do

            desc "Payment gateway webhook"
            route [:get, :post, :put] do
              response_payload = gateway.response(entry: entry, params: params, request: request) do
                processor.perform_with_access(
                  action_name: :webhook_capture,
                  accesses: class_context.processor_webhook_action_accesses,
                  action_arguments: webhook_action_arguments
                )
              end

              if response_payload.is_a?(String)
                header "Content-Type", "text/plain"
                response_payload
              else
                response_payload || { status: "ok" }
              end
            end
          end
          klass
        end
      end

    end
  end
end
