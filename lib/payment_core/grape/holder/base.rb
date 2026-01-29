module PaymentCore
  module Grape
    module Holder
      class Base < ::PaymentCore::Grape::Base

        include ::PaymentCore::Grape::Helpers::CurrentHolder

        def self.draw(opts = {}, &block)
          opts = { payment_methods: true, entries: true }.merge(opts || {})
          klass = duplicate(self)
          klass.class_exec(&block) if block_given?
          klass.namespace "holder/:holder_type/:holder_id" do
            mount(PaymentMethods.draw('payment_methods')) if opts.fetch(:payment_methods, true)
            mount(Entries.draw('entries')) if opts.fetch(:entries, true)
          end
          klass
        end

      end
    end
  end
end
