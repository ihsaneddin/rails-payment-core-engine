module PaymentCore
  module Grape
    autoload :Base,        'payment_core/grape/base'
    autoload :Admin,       'payment_core/grape/admin'
    autoload :Holder,      'payment_core/grape/holder'
    autoload :Resources,   'payment_core/grape/resources'
    autoload :Webhooks,    'payment_core/grape/webhooks'
    autoload :Helpers,     'payment_core/grape/helpers'
    autoload :Presenters,  'payment_core/grape/presenters'
  end
end
