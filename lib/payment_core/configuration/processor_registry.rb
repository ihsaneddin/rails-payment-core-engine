module PaymentCore
  module Configuration
    class ProcessorRegistry
      include Singleton

      def initialize
        @registry = Set.new
      end

      def register(processor_class, force: false)
        @registry << processor_class
      end

      def fetch(method_type)
        match = @registry.find do |klass|
          Object.const_get(klass).method_type.to_s == method_type.to_s
          rescue NameError
            false
        end
        unless match
          raise ::PaymentCore::Errors::UnknownProcessorError,
                "No processor registered for method_type: #{method_type}"
        end

        match.constantize
      end

      def resolve(method_type)
        fetch(method_type)
      end

      def freeze!
        @registry.freeze
      end

      def self.register(...) = instance.register(...)
      def self.fetch(...) = instance.fetch(...)
      def self.resolve(...) = instance.resolve(...)
      def self.setup &block
        raise "Block is not provided" unless block_given?
        block.arity.zero? ? instance_eval(&block) : yield(self)
      end
    end
  end
end