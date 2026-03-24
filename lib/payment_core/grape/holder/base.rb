module PaymentCore
  module Grape
    module Holder
      class Base < ::PaymentCore::Grape::Base

        include ::PaymentCore::Grape::Helpers::CurrentHolder
        include ::PaymentCore::Grape::Helpers::PaymentMethods

        def self.draw(opts = {}, &block)
          opts = { payment_methods: true, entries: true }.merge(opts || {})
          klass = duplicate(self)
          klass.class_exec(&block) if block_given?
          klass.namespace "holder/:holder_type/:holder_id" do
            if opts.fetch(:payment_methods, true)
              mount(
                ::PaymentCore::Grape::Resources::PaymentMethods.draw("payment_methods", create: false, update: false, destroy: false) do
                  self.processor_action_accesses = ::PaymentCore::Grape::Holder::PaymentMethods.processor_action_accesses
                  self.given_context = ::PaymentCore::Grape::Holder::PaymentMethods.given_context

                  query_scope do |_query|
                    if route.options[:action_name] == "update"
                      current_holder.payment_methods
                    else
                      current_holder.payment_method_candidates
                    end
                  end
                end
              )

              resource "payment_methods" do
                desc "Get list of holder available payment methods"
                get "available", authorize: [:read, :payment_methods],
                      model_name: proc { ::PaymentCore::PaymentMethod },
                      action_name: "available" do
                  presenter current_holder.payment_method_candidates.select { |rec| rec.available?(context: given_context, holder: current_holder) },
                            presenter_name: "PaymentCore::Grape::Presenters::PaymentMethod",
                            locals: presenter_local_options
                end
              end
            end
            mount(::PaymentCore::Grape::Resources::Entries.draw('entries')) if opts.fetch(:entries, true)
          end
          klass
        end

      end
    end
  end
end
