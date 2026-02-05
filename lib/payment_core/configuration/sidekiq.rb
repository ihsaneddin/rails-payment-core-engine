module PaymentCore
  module Configuration
    module Sidekiq

      mattr_accessor :options
      @@options = { queue: "payment_core", retry: 3 }

      mattr_accessor :worker_class
      @@worker_class = "PaymentCore::Worker"

      mattr_accessor :enable_scheduler
      @@enable_scheduler = true

      mattr_accessor :append_queue
      @@append_queue = true

      class << self

        def setup &block
          if block_given?
            block.arity.zero? ? instance_eval(&block) : yield(self)
          end
        end

        def append_options params= {}
          @@options.merge!(params)
        end

        def worker_class_constant
          @@worker_class.constantize
        end

        private

        def load_schedule_hash
          schedule_file = schedule_file_path
          return unless schedule_file && File.exist?(schedule_file)

          schedule_data = YAML.load_file(schedule_file)
          return unless schedule_data.is_a?(Hash)

          sidekiq_scheduler_version = ::SidekiqScheduler::VERSION.to_i
          schedule_data.dig(:versions, sidekiq_scheduler_version) || schedule_data
        end

        def schedule_file_path
          app_file = Rails.root.join("config", "payment_core_schedule.yml")
          return app_file if app_file.exist?

          PaymentCore::Engine.root.join("config", "payment_core_schedule.yml")
        end

        def apply_schedule(cfg, schedule_hash)
          return unless schedule_hash.present?

          sidekiq_scheduler_version = ::SidekiqScheduler::VERSION.to_i
          schedule = (::Sidekiq.schedule || {}).dup.merge(schedule_hash)

          case sidekiq_scheduler_version
          when 4
            cfg.schedule = schedule
          else
            ::Sidekiq.schedule = schedule
          end

          ::SidekiqScheduler::Scheduler.instance.reload_schedule!
        end

        def append_queue_to(cfg, queue)
          queue = queue.to_s
          queues = Array(cfg[:queues]).map(&:to_s)
          queues << queue unless queues.include?(queue)
          cfg[:queues] = queues

          if ::Sidekiq.respond_to?(:default_configuration) && ::Sidekiq.default_configuration.respond_to?(:queues=)
            ::Sidekiq.default_configuration.queues = queues
          elsif ::Sidekiq.respond_to?(:options) && ::Sidekiq.options.is_a?(Hash)
            ::Sidekiq.options[:queues] = queues
          end
        end

      end

    end
  end
end
