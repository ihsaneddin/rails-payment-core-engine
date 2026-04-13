module PaymentCore
  module Holder
    class PaymentMethodsController < BaseController
      include ::PaymentCore::Controllers::Concerns::PaymentMethods

      fetch_resource_and_collection! do
        model_klass "PaymentCore::PaymentMethod"
        resource_var_name :payment_method
        query_scope do |_query|
          current_holder.payment_method_candidates
        end
        resourceful_for :available do
          query_scope do |_query|
            current_holder.payment_method_candidates.select do |payment_method|
              payment_method.available?(context: given_context, holder: current_holder)
            end
          end
        end
      end

      before_action :fetch_resource, only: [:show, :member_processor_action]
      before_action :fetch_resources, only: [:index, :available, :collective_processor_action]

      def index; end

      def show; end

      def available; end

      def collective_processor_action
        handle_processor_action
      end

      def member_processor_action
        handle_processor_action
      end

      private

      def handle_processor_action
        entry = perform_processor_action
        if entry.errors.any?
          redirect_back fallback_location: holder_payment_methods_path(holder_type: holder_type, holder_id: holder_id),
                        alert: entry.errors.full_messages.to_sentence
        else
          target_entry = redirect_target_entry(entry)
          redirect_to holder_entry_path(holder_type: holder_type, holder_id: holder_id, id: target_entry.id),
                      notice: "Processor action completed."
        end
      rescue StandardError => e
        redirect_back fallback_location: holder_payment_methods_path(holder_type: holder_type, holder_id: holder_id),
                      alert: e.message
      end

      def redirect_target_entry(entry)
        return entry.components.first if entry.respond_to?(:components) && entry.components.present?

        entry
      end
    end
  end
end
