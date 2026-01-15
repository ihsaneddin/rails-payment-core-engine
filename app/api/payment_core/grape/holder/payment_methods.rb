module PaymentCore
  module Grape
    module Holder
      class PaymentMethods < Base

        add_resource_actions :action
        inheritable_class_attribute :processor_action_accesses
        self.processor_action_accesses = [:public]

        fetch_resource_and_collection! do
          model_klass do
            "PaymentCore::PaymentMethod"
          end
          query_scope do |query|
            if route.options[:action_name] == "update"
              current_holder.payment_methods
            else
              current_holder.payment_method_candidates
            end
          end
        end

        include PaymentCore::Grape::Helpers::PaymentMethods

        resource "payment_methods" do
          desc "Get list of holder payment methods"
          get "", authorize: [:read, :payment_core_payment_method ],
                model_name: "PaymentCore::PaymentMethod",
                action_name: "index" do
            presenter records, locals: presenter_local_options
          end

          desc "Get list of holder available payment methods"
          get "available", authorize: [:read, :payment_core_payment_method ],
                model_name: "PaymentCore::PaymentMethod",
                action_name: "available" do
            presenter records.select{|rec| rec.available?(context: given_context, holder: current_holder) },
              locals: presenter_local_options
          end

          params do
            requires :method_type, type: String, regexp: /\A[A-Za-z_]+\z/
            optional :payment_method_ids, type: Array
          end
          resource ":method_type" do
            desc "Processor actions of payment method type"
            post ":processor_action", authorize: [:action, :payment_core_payment_method ],
                  model_name: "PaymentCore::PaymentMethod",
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

        resource "payment_method/:id" do
          desc "Update existing payment method "
          put "", authorize: [:update, :payment_core_payment_method ],
                model_name: "PaymentCore::PaymentMethod",
                action_name: "update" do
            if record.update permitted_attributes
              presenter record, locals: presenter_local_options
            else
              standard_validation_error(details: record.errors)
            end
          end

          desc "Processor actions of payment method"
          post ":processor_action", authorize: [:action, :payment_core_payment_method ],
                model_name: "PaymentCore::PaymentMethod",
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
    end
  end
end
