module PaymentCore
  module Grape
    module Holder
      class Base < ::PaymentCore::Grape::Base

        include ::PaymentCore::Grape::Helpers::PaymentMethodHolders

        def self.draw(opts = {}, &block)
          opts = { payment_methods: true, entries: true }.merge(opts || {})
          klass = duplicate(self)
          klass.class_exec(&block) if block_given?
          klass.namespace "holder/:holder_type/:holder_id" do
            if opts.fetch(:payment_methods, true)
              mount(
                ::PaymentCore::Grape::Resources::PaymentMethods.draw("payment_method", create: false, update: false, destroy: false) do
                  self.processor_action_accesses = [:public]

                  query_scope do |_query|
                    if route.options[:action_name] == "update"
                      payment_method_holder.payment_methods
                    else
                      payment_method_holder.payment_method_candidates
                    end
                  end

                  resources "payment_methods" do
                    desc "Get list of holder available payment methods"
                    get "available", authorize: [:read, :payment_methods],
                          model_name: proc { ::PaymentCore::PaymentMethod },
                          action_name: "available" do
                      presenter payment_method_holder.payment_method_candidates.select { |rec| rec.available?(context: given_context, holder: payment_method_holder) },
                                presenter_name: "PaymentCore::Grape::Presenters::PaymentMethod",
                                locals: presenter_local_options
                    end
                  end

                end
              )

            end
            if opts.fetch(:entries, true)
              mount(::PaymentCore::Grape::Resources::Entries.draw('entry') do
                query_scope do |query|
                  payment_method_holder.payment_entries
                end
              end)
            end
          end
          klass
        end

      end
    end
  end
end
