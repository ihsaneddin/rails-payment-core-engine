module PaymentCore
  module Grape
    module Holder
      class Base < ::PaymentCore::Grape::Base

        include ::PaymentCore::Grape::Helpers::CurrentHolder

        def self.draw(&block)
          klass = duplicate(self)
          klass.class_exec(&block) if block_given?
          klass.namespace "holder/:holder_type/:holder_id" do
            mount(PaymentMethods.draw('payment_methods'))
            mount(Entries.draw('entries'))
          end
          klass
        end

      end
    end
  end
end
