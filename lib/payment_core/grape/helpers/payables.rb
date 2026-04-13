module PaymentCore
  module Grape
    module Helpers
      module Payables

        def self.included(base)
          base.helpers HelperMethods
        end

        module HelperMethods

          def payable
            @payable ||= payable_class.payment_method_payable_api.finder(payable_id)
          end

          def payable_class
            ::PaymentCore::Models::Decorators::Payable.registered_classes.find{|klass| klass.payable_config.type.to_s.singularize == payable_type.singularize } ||
            raise { ::ActiveRecord::RecordNotFound }
          end

          def payable_type
            params[:payable_type]
          end

          def payable_id
            params[:payable_id]
          end

        end

      end

    end
  end
end