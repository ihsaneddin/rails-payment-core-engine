module PaymentCore
  module Grape
    class Base < ::Grape::API

      use_plugins_grape(PaymentCore.config.grape_api)

      format :json

      prefix api_config.prefix if api_config.prefix

      include PaymentCore::Grape::Helpers
      include PaymentCore::Grape::Helpers::Authenticate
      include PaymentCore::Grape::Helpers::Authorize

      resource_context("payment_core")

      def self.draw(opts = {}, &block)
        opts = { admin: true, holder: true, webhooks: true, namespace: nil }.merge(opts || {})
        klass = duplicate(self)
        klass.class_exec(&block) if block_given?

        mount_routes = proc do
          admin_opts = opts.fetch(:admin, true)
          holder_opts = opts.fetch(:holder, true)

          mount(::PaymentCore::Grape::Admin::Base.draw(**admin_opts)) if admin_opts.is_a?(Hash)
          mount(::PaymentCore::Grape::Admin::Base.draw) if admin_opts == true

          mount(::PaymentCore::Grape::Holder::Base.draw(**holder_opts)) if holder_opts.is_a?(Hash)
          mount(::PaymentCore::Grape::Holder::Base.draw) if holder_opts == true

          mount(::PaymentCore::Grape::Webhooks.draw) if opts.fetch(:webhooks, true)
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
