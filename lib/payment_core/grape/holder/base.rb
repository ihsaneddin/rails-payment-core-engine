module PaymentCore
  module Grape
    module Holder
      class Base < ::PaymentCore::Grape::Base

        include ::PaymentCore::Grape::Helpers::CurrentHolder

        namespace "holder/:holder_type/:holder_id" do
          mount(PaymentMethods.draw('payment_methods'))
          mount(Entries.draw('entries'))
        end

      end
    end
  end
end
