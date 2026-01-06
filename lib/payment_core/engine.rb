require 'sidekiq'
require 'sidekiq-scheduler'
require 'plugins/engine_callbacks'

module PaymentCore
  class Engine < ::Rails::Engine
    isolate_namespace PaymentCore
    config.generators.api_only = true

    config.to_prepare do
      Dir.glob(PaymentCore::Engine.root.join("lib/payment_core/processors/**/*.rb")).each do |file|
        require_dependency file rescue nil
      end
      Dir.glob(Rails.root.join("lib/payment_core/**/*.rb")).each do |file|
        require file rescue nil
      end

      unless Rails.env.production?
        Dir.glob(PaymentCore::Engine.root.join("app/models/payment_core/**/*.rb")).each do |file|
          require_dependency file rescue nil
        end
      end
    end

    extend ::Plugins::EngineCallbacks

    rake_tasks do
      Dir[File.join(__dir__, "../../tasks/**/*.rake")].each { |f| load f }
    end

    config.after_initialize do |app|
      Sidekiq.configure_server do |cfg|
        cfg.on :startup do
          PaymentCore::Engine.load_sidekiq_scheduler(cfg)
        end
      end
    end

    class << self

      def load_sidekiq_scheduler(cfg)
        sidekiq_scheduler_version = SidekiqScheduler::VERSION.to_i
        schedule_file = PaymentCore::Engine.root.join('config', 'payment_core_schedule.yml')
        return unless File.exist?(schedule_file)

        schedule_data = YAML.load_file(schedule_file)
        return unless schedule_data.is_a?(Hash)

        payment_core_schedule = schedule_data.dig(:versions, sidekiq_scheduler_version)

        case sidekiq_scheduler_version
        when 4
          if payment_core_schedule
            schedule = schedule.merge(payment_core_schedule)
            cfg.schedule= schedule
            queues = cfg[:queues] || []
          queues = queues + [PaymentCore.config.sidekiq.options[:queue]]
            SidekiqScheduler::Scheduler.instance.reload_schedule!
          end
        when 5
          if payment_core_schedule
            schedule = (Sidekiq.schedule || {}).dup
            schedule = schedule.merge(payment_core_schedule)
            Sidekiq.schedule= schedule
            Sidekiq.default_configuration.queues= cfg[:queues] + [PaymentCore.config.sidekiq.options[:queue]]
            SidekiqScheduler::Scheduler.instance.reload_schedule!
          end
        end
      end

      # def load_entries_decorators
      #   ::PaymentCore::Entry.descendants.each(&:after_engine_initialization)
      # end

    end

  end
end
