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

          attribute :use_intent_amount, default: false
          attribute :channel, :string
          attribute :payment_method_type, :string

          before_validation do
            apply_payment_method_defaults_from_parent if parent&.payment_method
          end

          def parent=(value)
            super(value)
            apply_payment_method_defaults_from_parent
          end

          def initialize(params = nil)
            params = params.is_a?(Hash) ? params : {}
            params.deep_symbolize_keys!
            payment_method_data = params[:payment_method_data]
            nested_data = params[:payment_method_data_attributes]
            payment_method_data =
              if payment_method_data.is_a?(Hash)
                payment_method_data
              elsif payment_method_data.respond_to?(:attributes)
                payment_method_data.attributes
              elsif payment_method_data.respond_to?(:to_h)
                payment_method_data.to_h
              else
                {}
              end
            if nested_data.is_a?(Hash)
              payment_method_data = payment_method_data.merge(nested_data)
            end
            payment_method_data = payment_method_data.deep_dup if payment_method_data.respond_to?(:deep_dup)
            payment_method_data[:method_type] ||= parent_method_type || params[:payment_method_type]
            if parent && parent.payment_method
              defaults = parent.payment_method.entry_method_data_defaults
              if defaults.is_a?(Hash)
                defaults = defaults.deep_symbolize_keys if defaults.respond_to?(:deep_symbolize_keys)
                payment_method_data = defaults.deep_merge(payment_method_data) do |_key, default_val, current_val|
                  current_val.nil? ? default_val : current_val
                end
              end
            end
            params[:payment_method_data] = payment_method_data
            params[:payment_method_data_attributes] = payment_method_data if nested_data.is_a?(Hash)
            super(params)
          end

          def parent_method_type
            payment_method = parent&.payment_method
            return unless payment_method

            payment_method.method_type.presence || payment_method.class.method_type
          end

          private

          def apply_payment_method_defaults_from_parent
            return unless parent.new_record?

            payment_method = parent&.payment_method
            return unless payment_method

            method_type = payment_method.method_type.presence || payment_method.class.method_type
            data_hash = {}
            if payment_method_data.respond_to?(:attributes)
              data_hash = payment_method_data.attributes
            elsif payment_method_data.is_a?(Hash)
              data_hash = payment_method_data
            elsif payment_method_data.respond_to?(:to_h)
              data_hash = payment_method_data.to_h
            end
            data_hash = data_hash.deep_symbolize_keys if data_hash.respond_to?(:deep_symbolize_keys)
            data_hash[:method_type] ||= method_type

            defaults = payment_method.entry_method_data_defaults
            if defaults.is_a?(Hash)
              defaults = defaults.deep_symbolize_keys if defaults.respond_to?(:deep_symbolize_keys)
              data_hash = defaults.deep_merge(data_hash) do |_key, default_val, current_val|
                current_val.nil? ? default_val : current_val
              end
            end

            self.payment_method_type = method_type
            self.payment_method_data = data_hash
          end

        end

      end
    end
  end
end
