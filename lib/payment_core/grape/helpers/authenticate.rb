module PaymentCore
  module Grape
    module Helpers
      module Authenticate
        def self.included(base)
          base.helpers HelperMethods
        end

        module HelperMethods

          def authenticate!
            super
            @current_user
          end

        end
      end
    end
  end
end