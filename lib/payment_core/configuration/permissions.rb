module PaymentCore
  module Configuration
    module Permissions

      class Permission < Plugins::Configuration::Permissions::Permission

        def initialize(name, _namespace: [], _priority: 0, _callable: true, **options, &block)
          super
          return unless _callable

          @model_name = options[:model_name]
          @subject = options[:subject]
          @action = options[:action] || name
          @with_identity = options[:with]
          @options = options.except(:model, :model_name, :subject, :action, :with, :_namespace, :_priority, :_callable)
          @block = block
        end

        def call(context, api, user, *args)
          return unless callable
          subject = @subject || @model_name.constantize
          if block_attached?
            context.can @action, subject, &@block.curry[*args]
          elsif @with_identity
            context.can @action, subject, @options.merge(@with_identity => user)
          else
            context.can @action, subject, @options
          end
        rescue NameError
          raise "You must provide a valid model name."
        end

        def block_attached?
          !!@block
        end

        # def call(context, api, *args)
        #   return unless callable
        #   return if @if.present? && !api.instance_exec(*args, &@if) rescue false
        #   subject = @subject || @model_name.constantize
        #   if block_attached?
        #     context.can @action, subject, &@block.curry[*args]
        #   else
        #     additional_options = if @condition_proc
        #         api.instance_exec(*args, &@condition_proc)
        #       else
        #         {}
        #       end
        #     context.can @action, subject, @options.merge(additional_options)
        #   end
        # rescue NameError
        #   raise "You must provide a valid model name."
        # end

      end

      class PermissionSet < Plugins::Configuration::Permissions::PermissionSet

        class << self

          def permission_class
            PaymentCore::Configuration::Permissions::Permission
          end

        end
      end

    end
  end
end