module PaymentCore
  class PaymentIntent < ::PaymentCore.config.application_record_base_constant

    self.table_name = "payment_core_payment_intents"

    include ::PaymentCore::Models::Decorators::PaymentIntent::Object

  end
end
