module Ewallet
  module CurrencyDecorator
    extend ActiveSupport::Concern

    included do
      belongs_to :reference, polymorphic: true
    end

  end
end