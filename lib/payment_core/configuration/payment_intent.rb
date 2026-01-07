module PaymentCore
  module Configuration
    module PaymentIntent

      mattr_accessor :metadata_base_class

      @@metadata_base_class = "PaymentCore::Attributes::PaymentIntents::Metadata"

      def self.metadata_base_class_constant
        @@metadata_base_class.constantize
      end

      def self.setup &block
        raise "Block is not provided" unless block_given?
        block.arity.zero? ? instance_eval(&block) : yield(self)
      end

    end
  end
end