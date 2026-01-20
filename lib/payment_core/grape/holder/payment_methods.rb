module PaymentCore
  module Grape
    module Holder
      class PaymentMethods < ::PaymentCore::Grape::Holder::Base

        add_resource_actions :action

        inheritable_class_attribute :processor_action_accesses, :given_context, :payment_method_type, :payment_method_class_finder

        self.payment_method_type = "payment_method"
        self.payment_method_class_finder = proc {|payment_method_type|
          ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes.find{|klass| klass.method_type.to_s == payment_method_type.to_s.singularize}
        }
        self.processor_action_accesses = [:public]
        self.given_context = lambda do
          builder = ::PaymentCore.config.payment_method.default_context_builder
          context_opts = params[:context] || {}
          context_opts[:payables] = payables(context_opts[:payables])
          context_opts = { user: current_user, data: params }.merge(context_opts)
          builder.is_a?(Proc) ? instance_exec(context_opts, &builder) : builder
        end

        include ::PaymentCore::Grape::Helpers::PaymentMethods

        fetch_resource_and_collection! do
          model_klass do
            payment_method_class
          end
        end

        class << self

          def draw(*args, &block)
            opts = args.extract_options!
            payment_method_type = args[0]
            return unless payment_method_type
            klass = duplicate(self, &block)
            opts = {index: true, available: true, create: true, processor_collective_actions: true, show: true, update: false, destroy: true, processor_actions: true}.merge(opts)
            subject = payment_method_type.to_s.to_sym
            resources_path = payment_method_type
            klass.resources "#{resources_path}" do
              if opts[:index]
                desc "Get list of holder payment methods"
                get "", authorize: [:read, subject ],
                      model_name: proc { model_klass },
                      action_name: "index" do
                  presenter records, locals: presenter_local_options
                end
              end
              if opts[:available]
                desc "Get list of holder available payment methods"
                get "available", authorize: [:read, subject ],
                      model_name: proc { model_klass },
                      action_name: "available" do
                  presenter records.select{|rec| rec.available?(context: given_context, holder: current_holder) },
                    locals: presenter_local_options
                end
              end
              if opts[:processor_collective_actions]
                params do
                  requires :method_type, type: String, regexp: /\A[A-Za-z_]+\z/
                  optional :payment_method_ids, type: Array
                end
                resource ":method_type" do
                  desc "Processor actions of payment method type"
                  post ":processor_action", authorize: [:action, subject ],
                        model_name: proc { model_klass },
                        action_name: "collective_action",
                        processor_action: true,
                        collective_action: true do
                    entry = processor.perform_with_access(
                      action_name: processor_action_name,
                      accesses: processor_action_accesses,
                      action_arguments: processor_action_arguments
                    )
                    if entry.errors.any?
                      standard_validation_error(details: entry.errors)
                    else
                      presenter entry, presenter_name: processor.presenter_of(processor_action_name, entry, resource_context: resource_context), locals: presenter_local_options
                    end
                  end
                end
              end

            end
            resource_path = payment_method_type.to_s.singularize
            klass.resource "#{resource_path}/:id" do
              if opts[:show]
                desc "Show existing payment method "
                get "", authorize: [:read, subject ],
                      model_name: proc { model_klass },
                      action_name: "show" do
                  presenter record, locals: presenter_local_options
                end
              end
              if opts[:update]
                desc "Update existing payment method "
                put "", authorize: [:update, subject ],
                      model_name: proc { model_klass },
                      action_name: "update" do
                  if record.update permitted_attributes
                    presenter record, locals: presenter_local_options
                  else
                    standard_validation_error(details: record.errors)
                  end
                end
              end

              if opts[:processor_actions]
                desc "Processor actions of payment method"
                post ":processor_action", authorize: [:action, subject ],
                      model_name: proc { model_klass },
                      action_name: "action",
                      processor_action: true do
                  entry = processor.perform_with_access(
                    action_name: processor_action_name,
                    accesses: processor_action_accesses,
                    action_arguments: processor_action_arguments
                  )
                  if entry.errors.any?
                    standard_validation_error(details: entry.errors)
                  else
                    presenter entry, presenter_name: processor.presenter_of(processor_action_name, entry, resource_context: resource_context), locals: presenter_local_options
                  end
                end
              end

            end
            klass
          end

        end

      end
    end
  end
end
