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
              define_metadata_class(metadata_class)
              define_inheritable_singleton_method(:credentials?) { true }
              include InstanceMethods
            end

            def credentials?
              false
            end

          end

          module InstanceMethods
            def as_json(options = nil)
              data = super(options)
              fields = credentials_config.fields.keys
              return data unless data.is_a?(Hash) && fields.any?

              metadata = data["metadata"]
              if metadata.is_a?(Hash)
                data["metadata"] = metadata.except(*fields.map(&:to_s))
              end
              data.except(*fields.map { |field| "metadata_#{field}" })
            end
          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object

        end
      end
    end
  end
end
