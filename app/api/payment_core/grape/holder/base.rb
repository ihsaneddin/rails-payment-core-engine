module PaymentCore
  module Grape
    module Holder
      class Base < ::PaymentCore::Grape::Base

        include PaymentCore::Grape::Helpers::CurrentHolder

        namespace "holder/:holder_type/:holder_id" do
          mount PaymentMethods
          mount Entries
        end

      end
    end
  end
end
