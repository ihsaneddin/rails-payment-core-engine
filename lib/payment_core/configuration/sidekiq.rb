module PaymentCore
  module Configuration
    module Sidekiq

      mattr_accessor :options
      @@options = { queue: "payment_core", retry: 3 }

      mattr_accessor :worker_class
      @@worker_class = "PaymentCore::Worker"

      class << self

        def self.setup &block
          block.arity.zero? ? instance_eval(&block) : yield(self)
        end

        def append_options params= {}
          @@options.merge!(params)
        end

        def worker_class_constant
          @@worker_class.constantize
        end

      end

    end
  end
end