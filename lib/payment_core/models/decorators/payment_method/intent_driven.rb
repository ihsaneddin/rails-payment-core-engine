module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module IntentDriven

          extend ::Plugins::Decorators::ConfigBuilder

          def self.included base
            invalid_class?(base)
            base.extend ClassMethods
          end

          module Metadata
            extend ActiveSupport::Concern
            included do

              attribute :require_intent, :boolean, default: true

            end

          end

          def self.default_options
            {
              default: true,
              require: :require_intent?
            }
          end

          module ClassMethods

            def intent_driven(**opts, &block)

               default_opts = ::PaymentCore::Models::Decorators::PaymentMethod::IntentDriven.default_options
              ::PaymentCore::Models::Decorators::PaymentMethod::IntentDriven.plugins_config.setup(self, 'intent_driven_config', opts, default_opts, &block)

              metadata_class = patch_store_model_class!(base: store_model_klass_of(:metadata), mod: Metadata, name: :RequireIntentMetadata)
              define_metadata_class(metadata_class)

              define_inheritable_singleton_method(:intent_driven?) { true }

              after_initialize do
                self.metadata.require_intent = intent_driven_config.default
              end

              entry_callback :validate do |entry|
                if require_intent?
                  if entry.payment_intent.blank?
                    entry.errors.add(:payment_intent, :required)
                  else
                    entry.errors.add(:payment_intent, :invalid) unless entry.payment_intent.valid_to_be_used?
                  end
                end
              end

              entry_callback :after_save do |entry|
                if require_intent?
                  if entry.after_state_succeeded?
                    entry.payment_intent.confirm
                  end
                end
              end

              include InstanceMethods

            end

            def intent_driven?
              false
            end

          end

          module InstanceMethods
            def require_intent?
              self.metadata.require_intent
            end
          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object

        end
      end
    end
  end
end
