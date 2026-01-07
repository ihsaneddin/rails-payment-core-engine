module PaymentCore
  class PaymentMethod < ::PaymentCore.config.application_record_base_constant

    self.table_name = "payment_core_payment_methods"

    #core
    include ::PaymentCore::Models::Decorators::PaymentMethod::Object

  end
end
