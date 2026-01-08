module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module UsesReference

          extend ::Plugins::Decorators::ConfigBuilder

          def self.included base
            invalid_class?(base)
            base.extend ClassMethods
          end

          def self.default_options
            {
              required: true,
              use_reference: true,
              use_reference_attributes: true
            }
          end

          module ClassMethods

            def uses_reference(**opts, &block)
              default_opts = ::PaymentCore::Models::Decorators::PaymentMethod::UsesReference.default_options
              ::PaymentCore::Models::Decorators::PaymentMethod::UsesReference.config_class.setup(self, 'use_reference_config', opts, default_opts, &block)

              with_options if: proc { |record| record.use_reference_config.use_reference } do
                before_validation do
                  self.use_reference = true
                end
              end
              with_options if: proc { |record| record.use_reference_config.use_reference_attributes } do
                before_validation do
                  sync_payment_method_reference_attributes
                end
              end
              with_options if: proc { |record| record.use_reference_config.required } do
                validates :reference, presence: true
              end
              with_options if: :reference do
                validate do
                  errors.add(:reference, :invalid) unless valid_reference?
                end
                validate do
                  unless self.class <= reference.payment_method_type
                    errors.add(:type, :invalid)
                  end
                end
              end

              define_inheritable_singleton_method(:uses_reference?) { true }
              include InstanceMethods
            end

          end

          module InstanceMethods

            def valid_reference?
              reference && reference.class.include?(::PaymentCore.decorators.payment_method_reference_object)
            end

            def reference_attributes
              return @reference_attributes if @reference_attributes
              if reference && valid_reference?
                hash = {}
                ref_data = reference.payment_method_reference_attributes(self) || {}
                metadata_class = self.class.attribute_types['metadata'].model_klass
                ([:number, :display_name, :expires_at, :active, :default, :holder, :holder_id, :holder_type, :always_available] + metadata_class.assignable_attributes.map(&:to_sym)).each do |key|
                  hash[key] = ref_data[key] if ref_data.key?(key)
                end
                @reference_attributes = hash
              end
              @reference_attributes || {}
            end

            def sync_payment_method_reference_attributes
              reference_attributes.each do |k,v|
                if respond_to?(k)
                  send("#{k}=", v)
                end
              end
            end

            def sync_payment_method_reference_attributes!
              sync_payment_method_reference_attributes
              save
            end

          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object

        end
      end
    end
  end
end
