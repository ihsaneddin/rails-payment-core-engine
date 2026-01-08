module PaymentCore
  class PaymentIntentWorker < PaymentCore.config.sidekiq.worker_class_constant

    sidekiq_options(**PaymentCore.config.sidekiq.options)
    self.model = PaymentCore::PaymentIntent

    def schedule(metadata={})
      now = Time.at(metadata["scheduled_at"]).to_datetime rescue DateTime.now
      tomorrow = now.next.end_of_day
      model
      .pending?
      .expires_on_date(tomorrow)
      .each do |intent|
        intent.schedule_for_expiration
      end
    end

    def expiry
      resource do |intent|
        if intent
          intent.should_be_expired?
        end
      end
    end

  end
end