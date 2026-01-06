module PaymentCore
  module EntryDecorator
    extend ActiveSupport::Concern

    included do
      acts_as_ewallet_entry_reference
    end
  end
end