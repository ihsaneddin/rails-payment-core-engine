module PaymentCore
  module Grape
    module Admin
      class Base < ::PaymentCore::Grape::Base

        def self.draw(opts = {}, &block)
          opts = {
            payment_methods: true,
            entries: true,
            namespace: "admin"
          }.merge(opts || {})

          klass = duplicate(self)
          klass.helpers do
            def current_user
              @current_user ||= instance_exec(&api_config.authenticate_admin) if api_config.authenticate_admin.is_a?(Proc)
            end

            def current_admin
              @current_admin ||= current_user
            end
          end
          klass.class_exec(&block) if block_given?

          mount_routes = proc do
            if opts.fetch(:payment_methods, true)
              ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes.each do |payment_method_class|

                mount(
                  ::PaymentCore::Grape::Resources::PaymentMethods.draw(
                    payment_method_class.payment_method_name,
                    processor_collective_actions: payment_method_class.base_class == payment_method_class,
                    processor_actions: payment_method_class.base_class == payment_method_class
                  ) do
                    self.skip_processor_action_access_validation = true

                    query_scope do |query|
                      query.where.not(id: nil)
                    end

                    helpers do
                      def current_holder
                        nil
                      end
                    end
                  end
                )
              end
            end
            mount(::PaymentCore::Grape::Resources::Entries.draw("entries", create: false, update: false, destroy: false, resources_actions: false, resource_actions: false)) if opts.fetch(:entries, true)
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
