# Rails.application.config.to_prepare do
#   loader = Rails.autoloaders.main

#   loader.on_load do |loader, constant, file|
#     # Implement custom logging logic here
#     # For example, only log files from a specific directory
#     if file.include?("lib/payment_core")
#       Rails.logger.info("Zeitwerk loaded custom payment_core models: #{constant} from #{file}")
#     end
#   end
# end


require_dependency Rails.root.join("lib/payment_core/entry_decorator").to_s
require_dependency Rails.root.join("lib/ewallet/account_decorator").to_s
require_dependency Rails.root.join("lib/ewallet/currency_decorator").to_s

Rails.application.config.after_initialize do
  PaymentCore::Entry.include(PaymentCore::EntryDecorator)
  Ewallet::Account.include(Ewallet::AccountDecorator)
  Ewallet::Currency.include(Ewallet::CurrencyDecorator)
end
