module PaymentCore
  module Attributes
    class Base

      include StoreModel::Model
      include ActiveModel::Validations::Callbacks

      class_attribute :protected_attributes
      self.protected_attributes = []

      def self.inherited(subclass)
        super(subclass)
        subclass.protected_attributes = protected_attributes.dup
      end

      def self.assignable_attributes
        new.attributes.keys.reject { |att| protected_attributes.map(&:to_s).include?(att.to_s) }
      end

    end
  end
end
