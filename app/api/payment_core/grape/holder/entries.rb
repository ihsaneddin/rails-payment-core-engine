module PaymentCore
  module Grape
    module Holder
      class Entries < Base

        fetch_resource_and_collection! do
          model_klass do
            "PaymentCore::Entry"
          end
        end

        resource "entries" do
          desc "Get list of holder payment entries"
          get "", authorize: [:read, :payment_core_entry ],
                model_name: "PaymentCore::Entry",
                action_name: "index" do
            presenter records, locals: presenter_local_options
          end
        end

        resource "entry/:id" do
          desc "Get a holder entry"
          get "", authorize: [:read, :payment_core_entry ],
                model_name: "PaymentCore::Entry",
                action_name: "show" do
            presenter record, locals: presenter_local_options
          end
        end

      end
    end
  end
end
