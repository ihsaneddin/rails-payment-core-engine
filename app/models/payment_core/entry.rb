module PaymentCore
  class Entry < ::PaymentCore.config.application_record_base_constant

    self.table_name = "payment_core_entries"

    #core setup
    include ::PaymentCore::Models::Decorators::Entry::Object

  end
end
