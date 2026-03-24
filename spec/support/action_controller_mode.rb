module ActionControllerMode
  def with_action_controller_api
    original_enabled_api = PaymentCore.config.enabled_api

    PaymentCore.config.enabled_api = :action_controller
    redraw_payment_core_routes!
    yield
  ensure
    PaymentCore.config.enabled_api = original_enabled_api
    redraw_payment_core_routes!
  end

  def redraw_payment_core_routes!
    PaymentCore::Engine.routes.disable_clear_and_finalize = true
    PaymentCore::Engine.routes.clear!
    load PaymentCore::Engine.root.join("config/routes.rb")
    PaymentCore::Engine.routes_reloader&.execute_if_updated if PaymentCore::Engine.respond_to?(:routes_reloader)
  end
end

RSpec.configure do |config|
  config.include ActionControllerMode, type: :request
end
