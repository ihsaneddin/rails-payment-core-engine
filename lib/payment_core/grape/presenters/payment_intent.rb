module PaymentCore
  module Grape
    module Presenters
      class PaymentIntent < Base

        expose :details, merge: true

        private

          def details
            object.as_json(
              methods: [:type]
            )
          end

      end
    end
  end
end