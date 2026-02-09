module PaymentCore
  class PaymentIntentWorker < PaymentCore.config.sidekiq.worker_class_constant

    sidekiq_options(**PaymentCore.config.sidekiq.options)
    self.model = PaymentCore::PaymentIntent

    def schedule(metadata={})
      now = Time.at(metadata["scheduled_at"]).to_datetime rescue DateTime.now
      model
        .with_state(:pending)
        .where.not(expires_at: nil)
        .where("expires_at < ?", now)
        .find_each do |intent|
          intent.expiry
        end

      tomorrow = now.next.end_of_day
      model
      .with_state(:pending)
      .expires_on_date(tomorrow)
      .find_each do |intent|
        intent.schedule_for_expiration
      end
    end

    def expiry
      resource do |intent|
        if intent
          intent.expiry
        end
      end
    end

  end
end
