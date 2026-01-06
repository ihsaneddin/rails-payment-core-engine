module PaymentCore
  class PaymentMethod < ::PaymentCore.config.application_record_base_constant

    self.table_name = "payment_core_payment_methods"

    #core
    include ::PaymentCore::Models::Decorators::PaymentMethod::Object
    include ::Plugins::EngineCallbacks

    after_payment_core_initialization do
      default_payment_methods_builder = ::PaymentCore.config.payment_method.default_payment_methods_builder
      if default_payment_methods_builder && default_payment_methods_builder.is_a?(Proc)
        if ::ActiveRecord::Base.connection.table_exists?('payment_core_payment_methods')
          instance_exec(&default_payment_methods_builder)
        end
      end
    end
    grape_api_resource "payment_core", default: true do
      query_scope do |query_scope, api|
        api.current_holder.payment_method_candidates
      end
      resource_params_attributes do
        [
          :label_name, :active
        ]
      end
      presenter "PaymentCore::Grape::Presenters::PaymentMethod"
    end

    acts_as_paranoid if ::PaymentCore.config.soft_delete_enabled

    #relations
    has_many :entries, class_name: "PaymentCore::Entry", foreign_key: 'payment_method_id', dependent: :nullify


  end
end
