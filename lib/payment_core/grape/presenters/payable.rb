module PaymentCore
  module Grape
    module Presenters
      class Payable < Base

        expose :details, merge: true

        private

          def details
            object.as_json
          end

      end
    end
  end
end