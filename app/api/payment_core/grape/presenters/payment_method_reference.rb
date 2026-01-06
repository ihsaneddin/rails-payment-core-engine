module PaymentCore
  module Grape
    module Presenters
      class PaymentMethodReference < Base

        expose :details, merge: true

        private

          def details
            object.as_json.merge({type: object.type})
          end

      end
    end
  end
end