module PaymentCore
  class PaymentMethodReferenceWorker < PaymentCore.config.sidekiq.worker_class_constant

    sidekiq_options(**PaymentCore.config.sidekiq.options)
    self.model = nil

    def attributes_sync(reference_class, reference_id)
      ref_constant = reference_class.constantize
      return if ref_constant.include?(PaymentCore.decorators.payment_method_reference_object)
      ref = ref_constant.find(reference_id)
      if ref
        ref.sync_payment_method
      end
    end

  end
end