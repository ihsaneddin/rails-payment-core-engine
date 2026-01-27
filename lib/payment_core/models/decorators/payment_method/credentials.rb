module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module Credentials

          def self.included(base)
            invalid_class?(base)
            base.extend ClassMethods
          end

          def self.default_options
            {
              fields: {
                secret: true,
                client_id: true
              },
              encryption_key: proc {
                ::PaymentCore.config.payment_method.credentials_encryption_key
              }
            }
          end

          module Metadata
            extend ActiveSupport::Concern
            def as_json(options = {})
              data = super(options)
              fields = self.class.respond_to?(:credentials_fields) ? self.class.credentials_fields : []
              return data unless data.is_a?(Hash) && fields.any?
              data.except(*fields.map(&:to_s))
            end

          end

          module ClassMethods

            def credentials(**opts, &block)
              default_opts = ::PaymentCore::Models::Decorators::PaymentMethod::Credentials.default_options
              ::Plugins::Models::Concerns::Config.setup(self, 'credentials_config', opts, default_opts, &block)
              metadata_class = patch_store_model_class!(
                base: store_model_klass_of(:metadata),
                mod: Metadata,
                name: :CredentialsMetadata
              )
              base = self
              credentials_config.fields.each do |field, required|
                metadata_class.attribute(
                  field,
                  ::PaymentCore::AttributeTypes::EncryptedString.new(
                    key_resolver: base.credentials_config.encryption_key
                  )
                )
                metadata_class.validates field, presence: true if required
              end
              metadata_class.define_singleton_method(:credentials_fields) do
                base.credentials_config.fields.keys
              end
              define_metadata_class(metadata_class)
              define_inheritable_singleton_method(:credentials?) { true }
              include InstanceMethods
            end

            def credentials?
              false
            end

          end

          module InstanceMethods


          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object

        end
      end
    end
  end
end
