module PaymentCore
  module Configuration
    module Api

      include Plugins::Configuration::Api::Core

      self.authenticate = -> { User.first }

    end
  end
end