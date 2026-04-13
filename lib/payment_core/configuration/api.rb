module PaymentCore
  module Configuration
    module Api

      include Plugins::Configuration::Api::Core

      self.authenticate = -> { User.first }

      mattr_accessor :authenticate_admin
      @@authenticate_admin = -> { User.first }

      def self.authenticate_admin!(&block)
        self.authenticate_admin = block if block_given?
      end

    end
  end
end
