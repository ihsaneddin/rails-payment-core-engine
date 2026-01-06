module PaymentCore
  class Invoice < ::PaymentCore.config.application_record_base_constant

    self.table_name = "payment_core_invoices"

  end
end
