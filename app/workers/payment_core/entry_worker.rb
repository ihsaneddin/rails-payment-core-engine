module PaymentCore
  class EntryWorker < PaymentCore.config.sidekiq.worker_class_constant

    sidekiq_options(**PaymentCore.config.sidekiq.options)
    self.model = PaymentCore::Entry

    def check_status
      resource do |entry|
        return unless entry
        payment_method = entry.payment_method
        return unless payment_method&.method_type.to_s == "fiuu"

        context = entry.context || ::PaymentCore.config.payment_method.availability_context_class_constant.new(**{})
        processor = payment_method.processor(payer: entry.payer, context: context)
        processor.perform(:check_status, { entry_id: entry.id }, context)
      end
    end

  end
end
