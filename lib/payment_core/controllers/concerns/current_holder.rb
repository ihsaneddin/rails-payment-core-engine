module PaymentCore
  module Controllers
    module Concerns
      module CurrentHolder
        extend ActiveSupport::Concern

        included do
          helper_method :current_holder, :holder_class, :holder_type, :holder_id
        end

        def current_holder
          @current_holder ||= holder_class.payment_method_holder_api.finder(holder_id)
        end

        def holder_class
          @holder_class ||=
            ::PaymentCore::Models::Decorators::PaymentMethodHolder.registered_classes.find do |klass|
              klass.payment_method_holder_config.type.to_s == holder_type.to_s
            end || raise(ActiveRecord::RecordNotFound)
        end

        def holder_type
          params[:holder_type]
        end

        def holder_id
          params[:holder_id]
        end

        def ensure_current_holder!
          raise ActiveRecord::RecordNotFound unless current_holder&.payment_method_holder?
        end
      end
    end
  end
end
