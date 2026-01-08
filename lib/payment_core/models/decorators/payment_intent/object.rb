module PaymentCore
  module Models
    module Decorators
      module PaymentIntent
        module Object

          include ::Plugins.decorators.traits

          STATES = {
            pending: "pending",
            expired: "expired",
            confirmed: "confirmed",
            canceled: "canceled"
          }

          def invalid_class?(base)
            unless base.include?(::PaymentCore::Models::Decorators::PaymentIntent::Object)
              raise "Invalid : #{base.name} does not include #{::PaymentCore::Models::Decorators::PaymentIntent::Object} module"
            end
          end

          def self.registered_classes
            if @@registered_classes.blank?
              @@registered_classes << ::PaymentCore::PaymentIntent
            end
            @@registered_classes
          end

          def self.included(base)
            unless base <= ::PaymentCore::PaymentIntent
              raise "Invalid : #{base.name} is not a PaymentCore::PaymentIntent class"
            end

            base.include DepedencyHooks
            base.extend ClassMethods
            base.include Hooks
            base.extend Hooks::ClassMethods
            base.include RelationHooks
            base.extend RelationHooks::ClassMethods

            base.eventable_bus_name = base.name.demodulize.underscore.to_sym

            base.inheritable_class_attribute :intent_name
            base.intent_name= base.name.demodulize.underscore

            base.setup do
              register_cycle_events
              define_entry_relations
              define_enum_states(STATES)
              register_state_events
              register_state_method_helpers
            end

            base.include InstanceMethods

            ::PaymentCore::Models::Decorators::PaymentIntent::Object << base

            super(base) if defined?(super)

          end

          module DepedencyHooks
            extend ActiveSupport::Concern
            included do
              include ::Plugins::Models::Concerns::PolymorphicAlternative
              include ::Plugins::Models::Concerns::Eventable::PublishesEvents
              include ::Plugins::Models::Concerns::CustomAttributes
              include ::Plugins::Models::Concerns::RemoteCallbacks
              include ::Plugins::Models::Concerns::ApiResource
              include ::Plugins::Models::Concerns::IdempotencyLockable
              include ::Plugins::Models::Concerns::ThreadSafe
              include ::Plugins::Models::Concerns::TracksTransactionRoot
              include ::Plugins.decorators.inheritables.class_attributes
              include ::Plugins.decorators.hooks
              extend ::PaymentCore::Models::Decorators::Core
            end
          end

          module ClassMethods

            def setup &block
              instance_exec(&block) if block_given?
            end

            private

            def define_metadata_class(klass= ::PaymentCore.config.payment_entry.metadata_base_class_constant)
              custom_attributes_definition :metadata, klass, accessor: true
            end

            def define_enum_states(list_of_states = {})
              enum state: list_of_states
            end

            def register_state_events
              after_commit do
                if state.present? && state != state_before_last_save
                  publish_event("state.#{state}")
                end
              end
            end

            def register_cycle_events
              after_commit on: :create do
                publish_event(:created)
              end
              after_commit on: :update do
                publish_event(:updated)
              end
              after_commit on: :destroy do
                publish_event(:deleted)
              end
            end

            def register_state_method_helpers
              states.each do |k,v|
                define_method "after_state_#{k}?" do
                  saved_change_to_state? && state == k
                end

                define_method "state_will_be_#{k}?" do
                  will_save_change_to_state? && state == k
                end
              end
            end


          end

          module Hooks
            extend ActiveSupport::Concern

            included do

              scope :expires_on_date, ->(date) { where.not(expires_at: nil).where("DATE(expires_at) = ?", date) }

              before_save do
                if state_will_be_confirmed?
                  self.confirmed_at = Time.current
                end
              end
            end

            def schedule_for_expiration
              if expires_at && pending
                if expires_at.past?
                  PaymentCore::PaymentIntentWorker.perform_at(Time.current + 5.seconds, id, 'expiry')
                else
                  PaymentCore::PaymentIntentWorker.perform_at(expires_at, id, 'expiry')
                end
              end
            end

            module ClassMethods
              def inherited(subclass)
                super(subclass)
                subclass.intent_name= subclass.name.demodulize.underscore
                after_class_defined(subclass) do
                  ::PaymentCore::Models::Decorators::PaymentIntent::Object << subclass
                end
              end
            end
          end

          module RelationHooks
            extend ActiveSupport::Concern

            included do

              acts_as_paranoid if ::PaymentCore.config.soft_delete_enabled

              belongs_to :payable, polymorphic: true, optional: true

            end

            module ClassMethods
              def inherited subclass
                super(subclass)
                after_class_defined(subclass) do
                  ::PaymentCore.decorators.payable.payable_classes.each do |payable_class|
                    payable_class.payable_setup do
                      define_payable_payment_intent_relation(subclass)
                    end
                  end
                  ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.each do |klass|
                    klass.setup do
                      define_entry_relation(subclass)
                    end
                  end
                end
              end
              def payment_intent_relation_name_on_entry
                if self == base_class
                  :payment_intent
                else
                  "payment_intent_#{name.demodulize.underscore}".to_sym
                end
              end

              def payment_intent_relation_name_on_payable
                if self == base_class
                  :payable_payment_intents
                else
                  "payable_payment_intent_#{name.demodulize.underscore.pluralize}".to_sym
                end
              end

              private

              def define_entry_relations
                ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.each do |klass|
                  define_entry_relation(klass)
                end
              end

              def define_entry_relation(klass = ::PaymentCore::Entry)
                assoc_name = klass.entry_relation_name_on_payment_intent
                unless reflect_on_association(assoc_name)
                  if paranoid?
                    has_many assoc_name, -> { with_deleted }, class_name: klass.name, foreign_key: 'payment_intent_id'
                  else
                    has_many assoc_name, class_name: klass.name, foreign_key: 'payment_intent_id'
                  end
                end
              end
            end

          end

          module InstanceMethods

            def valid_to_be_used?
              should_be_expired?
              pending? || confirmed?
            end

            def should_be_expired?
              if pending?
                if expires_at.present? && expires_at.past?
                  expired!
                end
              end
            end

          end

        end
      end
    end
  end
end
