module PaymentCore
  module AttributeTypes
    class EncryptedString < ActiveModel::Type::String
      def initialize(key_resolver:, **_opts)
        @key_resolver = key_resolver
      end

      def serialize(value)
        return nil if value.nil?
        value = value.to_s
        return value if value.empty?
        encryptor.encrypt(value)
      end

      def deserialize(value)
        return nil if value.nil?
        value = value.to_s
        return value if value.empty?
        encryptor.decrypt(value)
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        nil
      end

      private

      def encryptor
        key = @key_resolver.respond_to?(:call) ? @key_resolver.call : @key_resolver
        raise "Missing credentials encryption key" if key.blank?
        Plugins::Models::Concerns::Preferences::Encryptor.new(key)
      end
    end
  end
end
