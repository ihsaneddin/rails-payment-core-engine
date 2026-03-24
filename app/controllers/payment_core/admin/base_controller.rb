module PaymentCore
  module Admin
    class BaseController < ::PaymentCore::ApplicationController
      include ::PaymentCore::Controllers::Concerns::AuthenticateAdmin

      resource_context "payment_core"
      self.resource_action_access = [:admin]
      self.collection_action_access = [:admin]
    end
  end
end
