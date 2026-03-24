Ewallet.setup do |config|
  config.set_default_issuer -> (*_args) { Ewallet::Issuer.default }
  config.set_default_currency "MYR"
  config.set_default_currencies ["MYR", "CR"]
end
