module PaymentCore
  module Holder
    class BaseController < ::PaymentCore::ApplicationController
      include ::PaymentCore::Controllers::Concerns::CurrentHolder

      resource_context "payment_core"
      self.resource_action_access = [:holder]
      self.collection_action_access = [:holder]

      before_action :ensure_current_holder!
    end
  end
end
