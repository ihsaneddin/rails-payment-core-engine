
Rails.application.config.after_initialize do
  Rails.autoloaders.main.eager_load_namespace(PaymentCore)
  PaymentCore::Entry.include(PaymentCore::EntryDecorator)
  Ewallet::Account.include(Ewallet::AccountDecorator)
  Ewallet::Currency.include(Ewallet::CurrencyDecorator)
end