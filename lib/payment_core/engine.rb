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
      ::Sidekiq.configure_server do |cfg|
        cfg.on :startup do
          ::PaymentCore.config.sidekiq.setup do
            append_queue_to(cfg, options[:queue]) if append_queue
            apply_schedule(cfg, load_schedule_hash) if enable_scheduler
          end
        end
      end
    end

  end
end
