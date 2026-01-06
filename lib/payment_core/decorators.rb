module PaymentCore
  module Decorators

    def self.payable
      ::PaymentCore::Models::Decorators::Payable
    end

    def self.payable_object
      payable::InstanceMethods
    end

    def self.payment_method_reference
      ::PaymentCore::Models::Decorators::PaymentMethodReference
    end

    def self.payment_method_reference_object
      payment_method_reference::InstanceMethods
    end

    def self.payment_method_holder
      ::PaymentCore::Models::Decorators::PaymentMethodHolder
    end

    def self.payment_method_holder_object
      payment_method_holder::InstanceMethods
    end

  end
end