module PaymentCore
  module Models
    module Decorators
      module Entry
        module RequiresProof

          extend ::Plugins::Decorators::ConfigBuilder

          def self.included base
            invalid_class?(base)
            base.extend ClassMethods
          end

          class Proof < PaymentCore::Attributes::Base

            attribute :file_url, :string
            attribute :note, :string

            validates :file_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true

          end

          module Metadata
            extend ActiveSupport::Concern
            included do

              attribute :requires_proofs, :boolean, default: nil
              attribute :proofs, Proof.to_array_type, default: []

              validates :proofs, store_model: true

            end

            def add_proof opts={}
              proof = if opts.is_a?(Proof)
                opts
              elsif opts.respond_to?(:to_h)
                Proof.new(opts.to_h)
              else
                Proof.new
              end
              list = Array(proofs).dup
              list << proof
              self.proofs = list
              proof
            end

            def update_proof index = -1, opts={}
              list = Array(proofs).dup
              proof = list[index]
              return nil unless proof

              attrs = if opts.is_a?(Proof)
                opts.attributes
              elsif opts.respond_to?(:to_h)
                opts.to_h
              else
                {}
              end
              proof.assign_attributes(attrs)
              self.proofs = list
              proof
            end

            def delete_proof(index=-1)
              list = Array(proofs).dup
              return nil if list.empty?

              removed = list.delete_at(index)
              self.proofs = list
              removed
            end

          end

          def self.default_options
            {
              default: true,
              required_condition: proc {
                metadata.requires_proofs
              },
              proofs: proc {
                metadata.proofs
              }
            }
          end

          module ClassMethods
            def requires_proof(**opts, &block)
               default_opts = ::PaymentCore::Models::Decorators::Entry::RequiresProof.default_options
              ::PaymentCore::Models::Decorators::Entry::RequiresProof.plugins_config.setup(self, 'proofs_config', opts, default_opts, &block)

              include InstanceMethods

              metadata_class = patch_store_model_class!(base: store_model_klass_of(:metadata), mod: Metadata, name: :ProofsMetadata)
              define_metadata_class(metadata_class)

              define_inheritable_singleton_method(:requires_proofs?) { true }

              after_initialize do
                self.metadata.requires_proofs ||= proofs_config.default
              end

              before_validation do
                self.metadata.requires_proofs = proofs_config.required_condition
              end

              validate if: :proof_required? do
                errors.add(:base, :proof_is_required) if proofs.blank?
              end

            end

            def requires_proofs?
              false
            end
          end

          module InstanceMethods

            def proof_required?
              proofs_config.required_condition
            end

            def proofs
              proofs_config.proofs
            end

          end

          extend ::PaymentCore::Models::Decorators::Entry::Object

        end
      end
    end
  end
end
