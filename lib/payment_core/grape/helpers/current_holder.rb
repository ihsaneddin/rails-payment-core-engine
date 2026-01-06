module PaymentCore
  module Grape
    module Helpers
      module CurrentHolder

        def self.included(base)
          base.helpers HelperMethods
        end

        module HelperMethods

          def current_holder
            @current_holder ||= holder_class.payment_method_holder_api.finder(holder_id)
          end

          def holder_class
            ::PaymentCore.decorators.payment_method_holder.holder_classes.find{|klass| klass.payment_method_holder_api.type == holder_type } ||
            raise { ::ActiveRecord::RecordNotFound }
          end

          def holder_type
            params[:holder_type]
          end

          def holder_id
            params[:holder_id]
          end

        end

      end

    end
  end
end