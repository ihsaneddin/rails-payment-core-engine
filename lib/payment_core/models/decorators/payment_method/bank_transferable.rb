module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module BankTransferable

          def self.included base
            invalid_class?(base)
            base.extend ClassMethods
          end

          ATTRIBUTES = [
              :bank_name,
              :bank_code,
              :bank_account_name,
              :bank_account_number,
              :instruction_text,
              :reference_hint,
              :default_currency
            ].freeze

          module Metadata
            extend ActiveSupport::Concern
            included do

              ATTRIBUTES.each do |att|
                attribute att, :string
              end

            end

          end

          module ClassMethods

            def bank_transferable(**opts, &block)

              metadata_class = patch_store_model_class!(base: store_model_klass_of(:metadata), mod: Metadata, name: :BankTransferableMetadata)
              define_metadata_class(metadata_class)


              ATTRIBUTES.each do |accessor_name|

                define_method(accessor_name) do
                  public_send(:metadata)&.public_send(accessor_name)
                end unless method_defined?(accessor_name)

                define_method("#{accessor_name}=") do |value|
                  public_send("metadata_#{accessor_name}=", value)
                  attribute_will_change!(accessor_name)
                  value
                end unless method_defined?("#{accessor_name}=")

                attribute accessor_name, :string

                scope "with_#{accessor_name}".to_sym, -> (*args) { send("with_metadata_#{accessor_name}", *args) }
                scope "like_#{accessor_name}".to_sym, -> (*args) { send("like_metadata_#{accessor_name}", *args) }

              end

              validates :bank_name, :bank_code, :bank_account_name, :bank_account_number, presence: true

              define_inheritable_singleton_method(:bank_transferable?) { true }

            end

            def bank_transferable?
              false
            end

          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object

        end
      end
    end
  end
end
