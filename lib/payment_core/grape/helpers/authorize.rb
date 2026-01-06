module PaymentCore
  module Grape
    module Helpers
      module Authorize
        def self.included(base)
          base.include Plugins::Grape::Concerns::Authorize
          base.helpers HelperMethods
          base.after_validation do
            authorize_route!
          end
        end

        module HelperMethods
          def authorize!(*args)
            if class_context.api_config.authorize.is_a?(Proc)
              instance_exec(*args, &class_context.api_config.authorize)
            else
              # do nothing
            end
          end

          def current_ability; end

          def skip_authorization!
            skip_authentication! || route_setting(:skip_authorization)
          end
        end
      end
    end
  end
end
