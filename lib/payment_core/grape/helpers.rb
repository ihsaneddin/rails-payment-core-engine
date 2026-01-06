module PaymentCore
  module Grape
    module Helpers
      autoload :Authenticate, "payment_core/grape/helpers/authenticate"
      autoload :Authorize, "payment_core/grape/helpers/authorize"
      autoload :CurrentHolder, "payment_core/grape/helpers/current_holder"
      autoload :PaymentMethods, "payment_core/grape/helpers/payment_methods"

      def self.included(base)
        base.helpers HelperMethods
      end

      module HelperMethods

        def presenter_local_options opts = params
          opts.merge({
            current_user: current_user,
            resource_context: resource_context
          })
        end

        def current_namespaces
          @namespaces ||= []
        end

      end

    end
  end
end