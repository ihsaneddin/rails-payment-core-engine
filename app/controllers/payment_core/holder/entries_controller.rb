module PaymentCore
  module Holder
    class EntriesController < BaseController
      fetch_resource_and_collection! do
        model_klass "PaymentCore::Entry"
        resource_var_name :entry
        query_scope do |_query|
          current_holder.payment_entries
        end
      end

      before_action :fetch_resources, only: :index
      before_action :fetch_resource, only: :show

      def index; end

      def show; end
    end
  end
end
