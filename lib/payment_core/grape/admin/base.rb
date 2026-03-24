module PaymentCore
  module Grape
    module Admin
      class Base < ::PaymentCore::Grape::Base
        class << self
          def registered_payment_method_resources
            ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes
              .reject { |klass| klass == ::PaymentCore::PaymentMethod }
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
                  ::PaymentCore::Grape::Resources::PaymentMethods.draw(payment_method_type.pluralize) do
                    self.payment_method_type = payment_method_type
                    self.skip_processor_action_access_validation = true

                    query_scope do |query_scope, _api|
                      query =
                        case query_scope
                        when ActiveRecord::Relation
                          query_scope
                        when ::PaymentCore::PaymentMethod
                          payment_method_class.where(id: query_scope.id)
                        else
                          payment_method_class.where.not(id: nil)
                        end

                      query.where(method_type: payment_method_type)
                    end

                    helpers do
                      def current_holder
                        return @current_holder if defined?(@current_holder)

                        @current_holder =
                          if processor_collective_action?
                            scope = records
                            scope = scope.where(id: params[:payment_method_ids]) if params[:payment_method_ids].present?
                            scope.first&.holder
                          else
                            record&.holder
                          end
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
