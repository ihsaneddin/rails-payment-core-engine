module PaymentCore
  module Configuration
    autoload :Api, "payment_core/configuration/api"
    autoload :GrapeApi, "payment_core/configuration/grape_api"
    autoload :Permissions, "payment_core/configuration/permissions"
    autoload :Models, "payment_core/configuration/models"
    autoload :ProcessorRegistry, "payment_core/configuration/processor_registry"
    autoload :Entry, "payment_core/configuration/entry"
    autoload :PaymentMethod, "payment_core/configuration/payment_method"

    include Plugins::Configuration::Core

    self.api= PaymentCore::Configuration::Api
    self.grape_api= PaymentCore::Configuration::GrapeApi
    self.permission_class= PaymentCore::Configuration::Permissions::Permission

    autoload :Sidekiq, "payment_core/configuration/sidekiq"

    mattr_accessor :sidekiq
    @@sidekiq = Sidekiq

    mattr_accessor :enabled_api
    @@enabled_api = :grape

    mattr_accessor :models
    @@models = ::PaymentCore::Configuration::Models.new

    mattr_accessor :application_record_base
    @@application_record_base = "PaymentCore::ApplicationRecord"

    def self.application_record_base_constant
      application_record_base.constantize
    end

    mattr_accessor :soft_delete_enabled
    @@soft_delete_enabled = true

    mattr_accessor :payment_processor_registry
    @@payment_processor_registry = ProcessorRegistry

    mattr_accessor :payment_entry
    @@payment_entry = PaymentCore::Configuration::Entry

    mattr_accessor :payment_method
    @@payment_method = ::PaymentCore::Configuration::PaymentMethod

    def self.payment_processor_registry &block
      if block_given?
        @@payment_processor_registry.setup(&block)
      else
        @@payment_processor_registry
      end
    end

    def self.payment_processor_registry &block
      if block_given?
        @@payment_processor_registry.setup(&block)
      else
        @@payment_processor_registry
      end
    end

    def self.payment_entry &block
      if block_given?
        @@payment_entry.setup(&block)
      else
        @@payment_entry
      end
    end

    def self.payment_method &block
      if block_given?
        @@payment_method.setup(&block)
      else
         @@payment_method
      end
    end

    def self.plugins_config
      ::Plugins::Models::Concerns::Config
    end

  end
end