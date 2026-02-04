module PaymentCore
  module Models
    module Decorators
      module PaymentIntent
        module Object

          include ::Plugins.decorators.traits

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
            base.include StateMachine
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

            def register_state_events
              after_save do
                if state.present? && state != state_before_last_save
                  publish_callback_event("state.#{state}")
                end
              end
            end

            def register_cycle_events
              after_create do
                publish_callback_event(:created)
              end
              after_update do
                publish_callback_event(:updated)
              end
              after_save do
                publish_callback_event(:saved)
              end
              after_destroy do
                publish_callback_event(:destroyed)
              end
            end

            def register_state_method_helpers
              state_machine(:state).states.each do |st|
                st_name = st.name
                define_method "after_state_#{st_name}?" do
                  saved_change_to_state? && state == st_name.to_s
                end
                define_method "state_will_be_#{st_name}?" do
                  will_save_change_to_state? && state == st_name.to_s
                end
              end
            end

          end

          module StateMachine
            extend ActiveSupport::Concern

             STATES = {
              pending: "pending",
              expired: "expired",
              confirmed: "confirmed",
              canceled: "canceled"
            }
            included do

              state_machine :state, initial: :pending do
                state(*STATES.keys)

                before_transition any => :confirmed do |entry|
                  entry.confirmed_at = Time.current
                end

                event :confirm do
                  transition pending: :confirmed
                end
                event :expiry do
                  transition pending: :expired
                end
                event :cancel do
                  transition pending: :canceled
                end

                state :expired do
                  validate :should_be_expired?
                end

              end

            end
          end
          module Hooks
            extend ActiveSupport::Concern

            included do

              define_inheritable_singleton_method :entry_callback do |*args, &block|
                opts = args.extract_options!
                callback_name = args[0]
                method_name = args[1]
                opts = { source: :payment_intent, if: true, exclusive: true }.merge(opts)
                ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.each do |klass|
                  callback_for(klass, callback_name, method_name, opts, &block)
                end
              end

              scope :expires_on_date, ->(date) { where.not(expires_at: nil).where("DATE(expires_at) = ?", date) }

              entry_callback :validate do |entry|
                if metadata.strict_entry_class
                  unless metadata.allowed_entry_classes.include?(entry.class.name)
                    entry.errors.add(:type, :entry_type_not_allowed)
                  end
                end
              end

            end

            def schedule_for_expiration
              if expires_at && pending?
                if expires_at.past?
                  PaymentCore::PaymentIntentWorker.perform_at(Time.current + 5.seconds, id, 'expiry')
                else
                  PaymentCore::PaymentIntentWorker.perform_at(expires_at + 1.second, id, 'expiry')
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
                  ::PaymentCore::Models::Decorators::Payable.registered_classes.each do |payable_class|
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
              not_expired! && (pending? || confirmed?)
            end

            def should_be_expired?
              expires_at.present? && expires_at.past? && pending?
            end

            def not_expired!
              expiry if should_be_expired?
              !expired?
            end

            protected

            def publish_callback_event(ename)
              publish_event(ename, prefix: "", bus: self.class.base_class.eventable_bus_name)
              publish_event(ename)
            end

          end

        end
      end
    end
  end
end
