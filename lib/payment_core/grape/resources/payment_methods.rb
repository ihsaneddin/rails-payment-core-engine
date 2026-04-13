module PaymentCore
  module Grape
    module Resources
      class PaymentMethods < ::PaymentCore::Grape::Resources::Base

        include ::PaymentCore::Grape::Helpers::PaymentMethods

        inheritable_class_attribute :processor_action_accesses, :given_context, :payment_method_name, :skip_processor_action_access_validation

        self.payment_method_name = "payment_method"

        self.processor_action_accesses = [:public]
        self.skip_processor_action_access_validation = false
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

        helpers do
          def perform_processor_action
            if class_context.skip_processor_action_access_validation
              processor.perform(
                processor_action_name,
                *processor_action_arguments
              )
            else
              processor.perform_with_access(
                action_name: processor_action_name,
                accesses: processor_action_accesses,
                action_arguments: processor_action_arguments
              )
            end
          end
        end

        class << self

          def draw(*args, &block)
            opts = args.extract_options!
            resource_name = args[0]
            return unless resource_name
            klass = duplicate(self, &block)
            klass.payment_method_name = resource_name
            opts = {
              index: true,
              create: true,
              resources_actions: true,
              processor_collective_actions: true,
              show: true,
              update: true,
              destroy: true,
              resource_actions: true,
              processor_actions: true
            }.merge(opts)
            subject = resource_name.to_s.singularize.to_sym

            resources_path = resource_name.to_s.pluralize
            klass.resources "#{resources_path}" do
              if opts[:index]
                desc "Get list of holder payment methods"
                get "", authorize: [:read, subject ],
                      model_name: proc { model_klass },
                      action_name: "index" do
                  presenter records, locals: presenter_local_options
                end
              end
              if opts[:create]
                desc "Create payment method"
                post "", authorize: [:create, subject ],
                      model_name: proc { model_klass },
                      action_name: "create" do
                  if record.save
                    presenter record, locals: presenter_local_options
                  else
                    standard_validation_error(details: record.errors)
                  end
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
                    entry = perform_processor_action
                    if entry.errors.any?
                      standard_validation_error(details: entry.errors)
                    else
                      presenter entry, presenter_name: processor.presenter_of(processor_action_name, entry, resource_context: resource_context), locals: presenter_local_options
                    end
                  end
                end
              end
              if opts[:resources_actions]
                namespace :action do
                  collection_actions_for(base.model_klass, base.resource_context, authorize: [:action, subject ], model_name: proc { model_klass }, action_name: "#{subject}_action")
                end
              end

            end
            resource_path = payment_method_name.to_s.singularize
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
                  entry = perform_processor_action
                  if entry.errors.any?
                    standard_validation_error(details: entry.errors)
                  else
                      presenter entry, presenter_name: processor.presenter_of(processor_action_name, entry, resource_context: resource_context), locals: presenter_local_options
                  end
                end
              end
              if opts[:resource_actions]
                namespace :action do
                  resource_actions_for(base.model_klass, base.resource_context, authorize: [:action, subject ], model_name: proc { model_klass }, action_name: "#{subject}_action")
                end
              end

            end
            klass
          end

          def draws(*args, &block)
            opts = args.extract_options!
            payment_method_names = args

            payment_method_names.map do |payment_method_name|
              draw(payment_method_name, opts, &block)
            end
          end

        end

      end
    end
  end
end
