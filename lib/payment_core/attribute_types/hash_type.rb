require "json"

module PaymentCore
  module AttributeTypes
    class HashType < ActiveModel::Type::Value
      def cast(value)
        case value
        when nil
          {}
        when Hash
          value
        when String
          JSON.parse(value) rescue {}
        else
          if value.respond_to?(:to_unsafe_h)
            value.to_unsafe_h
          elsif value.respond_to?(:to_h)
            value.to_h
          else
            {}
          end
        end
      end

      def serialize(value)
        value || {}
      end
    end
  end
end

ActiveModel::Type.register(:hash, ::PaymentCore::AttributeTypes::HashType)
