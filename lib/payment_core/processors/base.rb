module PaymentCore
  module Processors
    class Base

      include ::PaymentCore::Processors::Object

      def initialize(payment_method, **opts)
        @payment_method= payment_method
        @context = opts[:context]
        @payer = opts[:payer]
        @collective = opts[:collective]
        if @collective
          @payment_method = Array(payment_method) unless payment_method.is_a?(Array)
        else
          @payer ||= payment_method.holder
        end
      end

      action :charge do |params, *args|
        raise NotImplementedError, "#{self.class} must implement #charge"
      end

      params :charge_params do
        []
      end

      action :status do |params|
        raise NotImplementedError, "#{self.class} must implement #status"
      end

      params :status_params do
        []
      end

    end
  end
end