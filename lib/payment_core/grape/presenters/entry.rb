module PaymentCore
  module Grape
    module Presenters
      class Entry < Base

        expose :details, merge: true

        private

          def details
            object.as_json(
              include: {
                components: {
                  methods: [:type]
                }
              },
              methods: [:type]
            )
          end

      end
    end
  end
end