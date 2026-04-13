module PaymentCore
  module Admin
    class PaymentMethodsController < BaseController
      include ::PaymentCore::Controllers::Concerns::PaymentMethods

      fetch_resource_and_collection! do
        model_klass "PaymentCore::PaymentMethod"
        resource_var_name :payment_method
        query_scope do |query|
          query.where.not(id: nil)
        end
        resource_params_attributes do
          payment_method_resource_params_attributes
        end
        new_resource do |attrs|
          model = selected_payment_method_model
          model.new(normalized_payment_method_attributes(attrs, model))
        end
      end

      before_action :fetch_resource, only: [:new, :create, :show, :edit, :update, :destroy, :member_processor_action]
      before_action :fetch_resources, only: [:index, :collective_processor_action]

      def index; end

      def show; end

      def new; end

      def edit; end

      def create
        if resource.save
          redirect_to admin_payment_method_path(resource), notice: "Payment method created."
        else
          flash.now[:alert] = resource.errors.full_messages.to_sentence
          render :new, status: :unprocessable_entity
        end
      end

      def update
        attrs = normalized_payment_method_attributes(permitted_attributes, resource.class)
        if resource.update(attrs)
          redirect_to admin_payment_method_path(resource), notice: "Payment method updated."
        else
          flash.now[:alert] = resource.errors.full_messages.to_sentence
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if resource.destroy
          redirect_to admin_payment_methods_path, notice: "Payment method deleted."
        else
          redirect_to admin_payment_methods_path, alert: resource.errors.full_messages.to_sentence
        end
      end

      def collective_processor_action
        handle_processor_action
      end

      def member_processor_action
        handle_processor_action
      end

      private

      def skip_processor_action_access_validation?
        true
      end

      def current_processor_payer
        nil
      end

      def handle_processor_action
        entry = perform_processor_action
        if entry.errors.any?
          redirect_back fallback_location: admin_payment_methods_path,
                        alert: entry.errors.full_messages.to_sentence
        else
          target_entry = redirect_target_entry(entry)
          redirect_to admin_entry_path(id: target_entry.id), notice: "Processor action completed."
        end
      rescue StandardError => e
        redirect_back fallback_location: admin_payment_methods_path, alert: e.message
      end

      def redirect_target_entry(entry)
        return entry.components.first if entry.respond_to?(:components) && entry.components.present?

        entry
      end
    end
  end
end
