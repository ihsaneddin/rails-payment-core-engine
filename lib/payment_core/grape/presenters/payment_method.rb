module PaymentCore
  module Grape
    module Presenters
      class PaymentMethod < Base

        expose :details, merge: true
        expose :reference do |resource, options|
          if resource.use_reference && resource.reference_instance
            cfg = resource.reference_instance.grape_api_resource_of("payment_core")
            presenter = if cfg
              cfg.presenter.constantize
            else
              PaymentCore::Grape::Presenters::PaymentMethodReference
            end
            presenter.represent(resource.reference_instance, root: false, locals: options)
          end
        end

        private

          def details
            object.as_json.merge({type: object.type})
          end

      end
    end
  end
end