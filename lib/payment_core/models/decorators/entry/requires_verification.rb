module PaymentCore
  module Models
    module Decorators
      module Entry
        module RequiresVerification

          extend ::Plugins::Decorators::ConfigBuilder

          def self.included base
            invalid_class?(base)
            base.extend ClassMethods
          end

          class VerificationAttempt < ::PaymentCore::Attributes::Base

            attribute :requested_by, :string
            attribute :requested_at, :datetime, default: Time.current
            attribute :verified_by, :string
            attribute :verified_at, :datetime
            attribute :accepted, :boolean, default: nil
            attribute :reason, :string

          end

          module Metadata
            extend ActiveSupport::Concern
            included do

              attribute :requires_verification, :boolean, default: nil
              attribute :verification_attempts, VerificationAttempt.to_array_type, default: []

              accepts_nested_attributes_for :verification_attempts, reject_if: :all_blank

            end

            def last_verification_attempt(opts = {})
              verification_attempts.last&.assign_attributes(opts) || verification_attempts.build(opts)
            end

            def add_verification_attempt(opts = {})
              attempt = if opts.is_a?(VerificationAttempt)
                opts
              elsif opts.respond_to?(:to_h)
                VerificationAttempt.new(opts.to_h)
              else
                VerificationAttempt.new
              end
              list = Array(verification_attempts).dup
              list << attempt
              self.verification_attempts = list
              attempt
            end

            def update_verification_attempt(index = -1, opts = {})
              if index.is_a?(Hash) && opts.empty?
                opts = index
                index = -1
              end
              list = Array(verification_attempts).dup
              attempt = list[index]
              return nil unless attempt

              attrs = if opts.is_a?(VerificationAttempt)
                opts.attributes
              elsif opts.respond_to?(:to_h)
                opts.to_h
              else
                {}
              end
              attempt.assign_attributes(attrs)
              self.verification_attempts = list
              attempt
            end

            def delete_verification_attempt(index = -1)
              list = Array(verification_attempts).dup
              return nil if list.empty?

              removed = list.delete_at(index)
              self.verification_attempts = list
              removed
            end

          end

          def self.default_options
            {
              default: true,
              required_condition: proc {
                metadata.requires_verification
              },
              verified_condition: proc {
                metadata.verification_attempts.any?{|attempt| attempt.accepted }
              },
              max_attempt: nil
            }
          end

          module ClassMethods

            def verification(**opts, &block)
               default_opts = ::PaymentCore::Models::Decorators::Entry::RequiresVerification.default_options
              ::PaymentCore::Models::Decorators::Entry::RequiresVerification.plugins_config.setup(self, 'verification_config', opts, default_opts, &block)

              include StateMachine
              include InstanceMethods

              metadata_class = patch_store_model_class!(base: store_model_klass_of(:metadata), mod: Metadata, name: :VerificationMetadata)
              define_metadata_class(metadata_class)

              define_inheritable_singleton_method(:requires_verification?) { true }

              after_initialize do
                self.metadata.requires_verification ||= verification_config.default
              end

              before_validation do
                self.metadata.requires_verification = verification_config.required_condition
              end

            end

            def requires_verification?
              false
            end

          end

          module StateMachine
            extend ActiveSupport::Concern

            STATES = [:verification_pending, :verification_failed]

            included do

              state_machine do
                state(*STATES)
              end

              state_machine :verification, attribute: :state, namespace: :verification do
                state :verification_pending, :verification_failed
                before_transition any => :succeeded do |entry|
                  entry.succeeded_at = Time.current
                end
                event :request do
                  transition [:pending, :processing, :verification_failed] => :verification_pending, if: ->(entry, *args) { !entry.verification_attempts_exceeded?  }
                end
                event :reject do
                  transition [:verification_pending] => :verification_failed
                end
                event :accept do
                  transition [:verification_pending] => :succeeded
                end
              end

              before_state_transition :verification, to: :verification_pending do |request_params|
                next true unless verification_required?
                request_params = (request_params || {}).deep_symbolize_keys.slice(:requested_by, :requested_at)
                self.metadata.add_verification_attempt(request_params)
              end

              before_state_transition :verification, to: :succeeded do |attempt_params|
                next true unless verification_required?
                attempt_params = (attempt_params || {}).deep_symbolize_keys.slice(:verified_by, :verified_at).merge(accepted: true)
                self.metadata.update_verification_attempt(attempt_params)
              end

              before_state_transition :verification, to: :verification_failed do |attempt_params|
                next true unless verification_required?
                attempt_params = (attempt_params || {}).deep_symbolize_keys.slice(:verified_by, :verified_at).merge(accepted: false)
                self.metadata.update_verification_attempt(attempt_params)
              end

              before_state_transition to: :succeeded do
                !verification_required? || verified?
              end

            end

          end

          module InstanceMethods

            def verification_required?
              verification_config.required_condition
            end

            def verified?
              verification_config.verified_condition
            end

            def verification_attempts_exceeded?
              if verification_config.max_attempt
                metadata.verification_attempts.length >= verification_config.max_attempt
              end
            end
          end

          extend ::PaymentCore::Models::Decorators::Entry::Object

        end
      end
    end
  end
end
