module PaymentCore
  module Configuration
    module Entry

      mattr_accessor :metadata_base_class
      mattr_accessor :method_data_base_class

      @@metadata_base_class = "PaymentCore::Attributes::Entries::Metadata::Base"
      @@method_data_base_class = "PaymentCore::Attributes::Entries::MethodData::Base"

      def self.metadata_base_class_constant
        @@metadata_base_class.constantize
      end

      def self.method_data_base_class_constant
        @@method_data_base_class.constantize
      end

      def self.setup &block
        raise "Block is not provided" unless block_given?
        block.arity.zero? ? instance_eval(&block) : yield(self)
      end

    end
  end
end