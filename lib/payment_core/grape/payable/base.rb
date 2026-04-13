module PaymentCore
  module Grape
    module Payable
      class Base < ::PaymentCore::Grape::Base

        include ::PaymentCore::Grape::Helpers::Payables

        def self.draw(opts = {}, &block)
          opts = { entries: true, namespace: "payable/:payable_type/:payable_id" }.merge(opts || {})
          klass = duplicate(self)
          klass.class_exec(&block) if block_given?

          mount_routes = proc do
            if opts.fetch(:entries, true)
              mount(::PaymentCore::Grape::Resources::Entries.draw('entry') do
                query_scope do |query|
                  query.where(payable: payable)
                end
              end)
            end
          end

          if opts[:namespace].present?
            klass.namespace opts[:namespace] do
              instance_exec(&mount_routes)
            end
          else
            klass.instance_exec(&mount_routes)
          end

          klass
        end

      end
    end
  end
end
