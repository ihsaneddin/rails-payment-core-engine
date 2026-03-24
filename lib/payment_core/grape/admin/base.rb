module PaymentCore
  module Grape
    module Admin
      class Base < ::PaymentCore::Grape::Base
        class << self
          def registered_payment_method_resources
            ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes
              .select { |klass| klass.method_type.present? }
              .uniq { |klass| klass.method_type.to_s }
          end
        end

        def self.draw(opts = {}, &block)
          opts = {
            payment_methods: true,
            entries: true
          }.merge(opts || {})
          payment_method_resources = registered_payment_method_resources

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
          klass.namespace "admin" do
            if opts.fetch(:payment_methods, true)
              payment_method_resources.each do |payment_method_class|
                payment_method_type = payment_method_class.method_type.to_s
                mount(
                  ::PaymentCore::Grape::Resources::PaymentMethods.draw(
                    payment_method_type.pluralize,
                    processor_collective_actions: payment_method_class.base_class == payment_method_class,
                    processor_actions: payment_method_class.base_class == payment_method_class
                  ) do
                    self.payment_method_type = payment_method_type
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
          klass
        end
      end
    end
  end
end
