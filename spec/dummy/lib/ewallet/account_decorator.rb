module Ewallet
  module AccountDecorator
    extend ActiveSupport::Concern

    included do
      payment_method_reference 'payment_package' do
        attributes do
          {
            display_name: currency&.name,
            active: active?,
            always_available: false,
            expires_at: limited_time ? should_expire_at : nil,
            holder_type: holder.class.try(:base_class),
            holder_id: holder&.id
          }
        end
        functions do
          active :active?
          number :id
          balance :balance
          account_id :id
          currency do
            currency ? currency.name : nil
          end
          package do
            currency.reference
          end
        end
      end

      grape_api_resource "payment_core", default: true do
        presenter "Presenters::EwalletAccount"
      end

      after_create do
        if holder.present? && wallet.is_a?(Ewallet::Wallets::Open)
          create_payment_method_as_reference
        end
      end
    end
  end
end
