module PaymentCore
  module Grape
    module Helpers
      module PaymentMethodHolders

        def self.included(base)
          base.helpers HelperMethods
        end

        module HelperMethods

          def payment_method_holder
            @payment_method_holder ||= holder_class.payment_method_holder_api.finder(holder_id)
          end

          def current_holder
            payment_method_holder
          end

          def holder_class
            ::PaymentCore::Models::Decorators::PaymentMethodHolder.registered_classes.find{|klass| klass.payment_method_holder_config.type.to_s.singularize == holder_type.singularize } ||
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