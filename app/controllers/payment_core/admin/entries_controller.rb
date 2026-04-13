module PaymentCore
  module Admin
    class EntriesController < BaseController
      fetch_resource_and_collection! do
        model_klass "PaymentCore::Entry"
        resource_var_name :entry
        query_scope do |query|
          query.where.not(id: nil)
        end
      end

      before_action :fetch_resources, only: :index
      before_action :fetch_resource, only: :show

      def index; end

      def show; end
    end
  end
end
