module PaymentCore
  module Attributes
    module Entries
      module MethodData
        class Base < ::PaymentCore::Attributes::Base

          class_attribute :method_type_value, instance_writer: false
          class_attribute :registry
          self.registry = {}

          def self.inherited(subclass)
            super(subclass) if defined?(super)
            subclass.set_method_type_value
            if (key = subclass.method_type_value)
              self.registry[key.to_sym] = subclass
            end
          end

          def self.set_method_type_value tv= nil
            self.method_type_value = tv || self.name.demodulize.underscore
          end

          def self.registered_types
            descendants.inject({}) do |hash, subclass|
              hash[subclass.method_type_value.to_sym]= subclass
              hash
            end
          end

          def self.fetch_by_method_value_type val
            return ::PaymentCore::Attributes::Entries::MethodData::Base if val.nil?
            self.registered_types[val.to_sym] || ::PaymentCore::Attributes::Entries::MethodData::Base
          end

          attribute :method_type, :string

        end
      end
    end
  end
end
