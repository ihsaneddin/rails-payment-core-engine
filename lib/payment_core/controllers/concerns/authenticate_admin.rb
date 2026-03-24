module PaymentCore
  module Controllers
    module Concerns
      module AuthenticateAdmin
        extend ActiveSupport::Concern

        included do
          helper_method :current_admin
        end

        def current_user
          @current_user ||= instance_exec(&api_config.authenticate_admin) if api_config.authenticate_admin.is_a?(Proc)
        end

        def current_admin
          @current_admin ||= current_user
        end
      end
    end
  end
end
