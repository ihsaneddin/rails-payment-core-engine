module PaymentCore
  module Attributes
    module Entries
      module MethodData
        class FiuuMethod < ::PaymentCore.config.payment_entry.method_data_base_class_constant

          self.method_type_value = "fiuu"

          attribute :order_id, :string
          attribute :transaction_id, :string
          attribute :vcode, :string
          attribute :skey, :string
          attribute :redirect_url, :string
          attribute :redirect_path, :string
          attribute :status, :string
          attribute :flow, :string
          attribute :payment_method_code, :string
          attribute :bill_name, :string
          attribute :bill_email, :string
          attribute :bill_phone, :string
          attribute :bill_mobile, :string
          attribute :bill_desc, :string
          attribute :country, :string
          attribute :return_url, :string
          attribute :callback_url, :string
          attribute :notify_url, :string
          attribute :extended_vcode, :boolean
          attribute :mp_extended_vcode, :boolean
          attribute :gateway_request, ::PaymentCore::AttributeTypes::HashType.new
          attribute :gateway_response, ::PaymentCore::AttributeTypes::HashType.new
          attribute :webhook_payload, ::PaymentCore::AttributeTypes::HashType.new
          attribute :redirect_payload, ::PaymentCore::AttributeTypes::HashType.new

        end
      end
    end
  end
end
