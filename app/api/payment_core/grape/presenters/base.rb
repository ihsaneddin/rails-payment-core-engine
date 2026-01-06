module PaymentCore
  module Grape
    module Presenters
      class Base < ::Grape::Entity

        root "data", "data"

        def current_user
          locals[:current_user]
        end

        def locals
          options[:locals] || {}
        end

      end
    end
  end
end