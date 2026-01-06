module PaymentCore
  module Attributes
    module Entries
      module Metadata
        class Base < ::PaymentCore::Attributes::Base

          attribute :payment_method_data, StoreModel::Types::OnePolymorphic.new(proc { |value|
            value.deep_symbolize_keys!
            method_type = value[:method_type]
            ::PaymentCore::Attributes::Entries::MethodData::Base.fetch_by_method_value_type(method_type)
          })

          accepts_nested_attributes_for :payment_method_data

          attribute :purpose_code, :string
          attribute :note, :string
          attribute :channel, :string
          attribute :operator_class, :string
          attribute :operator_id, :string
          attribute :operator_name, :string
          attribute :payment_method_type, :string

          def initialize(params)
            params.deep_symbolize_keys!
            params[:payment_method_data] ||= {}
            params[:payment_method_data][:method_type] = parent_method_type || params[:payment_method_type]
            super(params)
          end

          def parent_method_type
            if parent && parent.payment_method
              parent.payment_method.class.method_type
            end
          end

        end

      end
    end
  end
end