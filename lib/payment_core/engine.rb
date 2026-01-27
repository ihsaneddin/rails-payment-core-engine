require 'sidekiq'
require 'sidekiq-scheduler'
require 'plugins/engine_callbacks'

module PaymentCore
  class Engine < ::Rails::Engine
    isolate_namespace PaymentCore
    config.generators.api_only = true

    initializer "payment_core.loader", before: :set_autoload_paths do |app|
      paths = []
      paths << { dir: ::PaymentCore::Engine.root.join('lib/payment_core/models').to_s, namespace: ::PaymentCore::Models}
      lpath = Rails.root.join("lib/payment_core")
      if lpath.exist?
        paths << { dir: lpath.to_s, namespace: ::PaymentCore}
      end
      paths.each do |path|
        Rails.autoloaders.main.push_dir(path[:dir], namespace: path[:namespace])
      end
    end

    config.before_initialize do |app|
      locales_path = Rails.root.join("lib/payment_core/config/locales")
      if locales_path.exist?
        app.config.i18n.load_path += Dir[locales_path.join("**/*.yml")]
      end
    end

    config.to_prepare do
      Rails.autoloaders.main.eager_load_namespace(::PaymentCore::Models)
      Rails.autoloaders.main.eager_load_namespace(::PaymentCore::Gateways)
      Rails.autoloaders.main.eager_load_namespace(::PaymentCore)
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
        if ::PaymentCore.config.sidekig.scheduler_enabled
          sidekiq_scheduler_version = SidekiqScheduler::VERSION.to_i
          schedule_file = PaymentCore::Engine.root.join('config', 'payment_core_schedule.yml')
          return unless File.exist?(schedule_file)

          schedule_data = YAML.load_file(schedule_file)
          return unless schedule_data.is_a?(Hash)

          payment_core_schedule = schedule_data.dig(:versions, sidekiq_scheduler_version)
          if payment_core_schedule.nil?
            payment_core_schedule = schedule_data
          end

          case sidekiq_scheduler_version
          when 4
            if payment_core_schedule
              schedule = schedule.merge(payment_core_schedule)
              cfg.schedule= schedule
              queues = cfg[:queues] || []
            queues = queues + [PaymentCore.config.sidekiq.options[:queue]]
              SidekiqScheduler::Scheduler.instance.reload_schedule!
            end
          else
            if payment_core_schedule
              schedule = (Sidekiq.schedule || {}).dup
              schedule = schedule.merge(payment_core_schedule)
              Sidekiq.schedule= schedule
              Sidekiq.default_configuration.queues= cfg[:queues] + [PaymentCore.config.sidekiq.options[:queue]]
              SidekiqScheduler::Scheduler.instance.reload_schedule!
            end
          end
        end
      end

      # def load_entries_decorators
      #   ::PaymentCore::Entry.descendants.each(&:after_engine_initialization)
      # end

    end

  end
end
