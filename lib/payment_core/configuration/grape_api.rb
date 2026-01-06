module PaymentCore
  module Configuration
    module GrapeApi

      include Plugins::Configuration::GrapeApi::Core

      self.base_api_namespace= "PaymentCore::Grape"
      self.base_endpoint_class= "PaymentCore::Grape::Base"
      self.authenticate = -> { User.first }

      mattr_accessor :authenticate_admin
      @@authenticate_admin = -> { User.first }

      def self.authenticate_admin! &block
        self.authenticate_admin= block if block_given?
      end

      mattr_accessor :load_models
      self.load_models = []

      def self.append_load_models models= []
        self.load_models = models + self.load_models
      end

      mattr_accessor :prefix, :version
      self.prefix= nil

    end
  end
end