module PaymentCore
  module Models
    module Decorators
      module Entry
        module Object

          include ::Plugins.decorators.traits

          def self.registered_directions
            registered_classes.to_a.map(&:direction).uniq
          end

          def self.registered_entry_types
            registered_classes.to_a.map(&:entry_type).uniq
          end

          def invalid_class?(base)
            unless base.include?(::PaymentCore::Models::Decorators::Entry::Object)
              raise "Invalid : #{base.name} does not include #{::PaymentCore::Models::Decorators::Entry::Object} module"
            end
          end

          def self.registered_classes
            if @@registered_classes.blank?
              @@registered_classes << ::PaymentCore::Entry
            end
            @@registered_classes
          end

          def self.included(base)
            unless base <= ::PaymentCore::Entry
              raise "Invalid : #{base.name} is not a PaymentCore::Entry class"
            end

            base.include DepedencyHooks
            base.include StateHooks
            base.extend ClassMethods
            base.include Hooks
            base.extend Hooks::ClassMethods
            base.include RelationHooks
            base.extend RelationHooks::ClassMethods

            base.eventable_bus_name = base.name.demodulize.underscore.to_sym

            base.inheritable_class_attribute :entry_type, :direction
            base.entry_type= base.name.demodulize.underscore

            base.setup do
              register_default_callbacks
              register_cycle_events
              register_state_events
              register_state_method_helpers
              define_state_alias_scopes
              define_payment_method_relations
              define_payment_intent_relations
            end


            base.attr_accessor :context
            base.include InstanceMethods

            ::PaymentCore::Models::Decorators::Entry::Object << base

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

          module StateHooks
            extend ActiveSupport::Concern

            # | Entry Direction| Allowed States                                                        | Notes                             |
            # | -------------- | --------------------------------------------------------------------- | --------------------------------- |
            # | **charge**     | `pending`, `processing`, `succeeded`, `failed`, `canceled`, `expired` | Most common stateful process      |
            # | **refund**     | `pending`, `processing`, `succeeded`, `failed`                        | No `expired`, rarely `canceled`   |
            # | **deposit**    | `succeeded`, `failed`, `pending`, `processing`                        | Often manually marked `succeeded` |
            # | **withdraw**   | `pending`, `processing`, `succeeded`, `failed`, `canceled`            | Typically async to a bank         |
            # | **transfer**   | `succeeded`, `failed`, `processing`                                   | Can be instantaneous or queued    |
            # | **adjustment** | `succeeded`, `failed`                                                 | Usually a one-time admin op       |
            # | **wrapper**    | `pending`, `succeeded`, `failed`                                  | for wrapper                       |

            STATES = {
                pending:       'pending',       # created, awaiting action
                processing:    'processing',    # in progress, may resolve async
                succeeded:     'succeeded',     # completed successfully
                failed:        'failed',        # terminal error
                canceled:      'canceled',      # intentionally voided
                expired:       'expired',       # timed out / no longer valid
                reversed:      'reversed',      # undone after success (rare)
                disputed:      'disputed',      # challenged by customer (card, etc)
            }

            included do

              state_machine :state, initial: :pending do
                state(*STATES.keys)

                before_transition any => :processing do |entry|
                  entry.processed_at = Time.current
                end
                before_transition any => :succeeded do |entry|
                  entry.succeeded_at = Time.current
                end

              end

            end

            class_methods do
              def before_state_transition *args, &block
                opts = args.extract_options!
                from = opts[:from]
                to = opts[:to]

                machine_names = args.blank? ? state_machines.keys : args
                machine_names.each do |machine_name|
                  machine_key = machine_name || :state
                  next unless state_machines.keys.include?(machine_key)
                  state_machine(machine_key) do
                    before_transition (from || any) => (to || any) do |record, transition|
                      args = transition.args.dup
                      kwargs = args.last.is_a?(Hash) ? args.pop : {}
                      record.instance_variable_set(:@_state_machine_transition, transition)
                      begin
                        record.instance_exec(*args, **kwargs, &block)
                      ensure
                        record.instance_variable_set(:@_state_machine_transition, transition)
                      end
                    end
                  end
                end
              end

              def after_state_transition *args, &block
                opts = args.extract_options!
                from = opts[:from]
                to = opts[:to]

                machine_names = args.blank? ? state_machines.keys : args
                machine_names.each do |machine_name|
                  machine_key = machine_name || :state
                  next unless state_machines.keys.include?(machine_key)
                  state_machine(machine_key) do
                    after_transition (from || any) => (to || any) do |record, transition|
                      args = transition.args.dup
                      kwargs = args.last.is_a?(Hash) ? args.pop : {}
                      record.instance_variable_set(:@_state_machine_transition, transition)
                      begin
                        record.instance_exec(*args, **kwargs, &block)
                      ensure
                        record.instance_variable_set(:@_state_machine_transition, transition)
                      end
                    end
                  end
                end
              end
            end

            def current_state_transition
              @_state_machine_transition
            end

          end

          module ClassMethods

            def wrap(entries=[], params={}, &block)
              result =
              if block_given?
                wrapper = PaymentCore::Entries::Wrapper.new(params)
                wrapper.idempotency_lock!(window: 5.seconds) do
                  begin
                    if wrapper.process
                      entries.each_with_index do |entry, i|
                        yield(entry, wrapper)
                        wrapper.components << entry
                        if wrapper.state != entry.parent.state
                          wrapper = entry.parent
                        end
                        entry.errors.each {|e| wrapper.errors.import e, **e.options.merge(attribute: "components.#{i}.#{e.attribute}")}
                      end
                    end
                    wrapper.success! if wrapper.errors.blank? && !wrapper.succeeded?
                    raise ActiveRecord::Rollback if wrapper.errors.any?
                  rescue => e
                    wrapper.errors.add(:base, e.message) unless wrapper.errors.any?
                    raise ActiveRecord::Rollback, e.message
                  end
                end
                wrapper.state = "failed" unless wrapper.persisted?
                wrapper
              end
              result = if result.nil?
                result = self.class.new
                result.errors.add(:id, :wrap_failed)
                result
              else
                result
              end
            end

            def setup &block
              instance_exec(&block) if block_given?
            end

            def method_missing(name, *args, &block)
              registered_entry_types = ::PaymentCore::Models::Decorators::Entry::Object.registered_entry_types
              registered_entry_types = registered_entry_types.to_a.map{|type| "#{type}?" }
              if registered_entry_types.include?(name.to_s)
                "#{self.entry_type}?" == name.to_s
              else
                super(name, *args, &block)
              end
            end

            def directions *args
              ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.select{|sub| args.map(&:to_s).include?(sub.direction) }
            end

            def entry_types *args
               ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.select{|sub| args.map(&:to_s).include?(sub.entry_type) }
            end

            private

            def define_metadata_class(klass= ::PaymentCore.config.payment_entry.metadata_base_class_constant)
              custom_attributes_definition :metadata, klass, accessor: true
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

            def register_default_callbacks
              before_validation do |entry|
                self.context ||= ::PaymentCore.config.payment_method.availability_context_class_constant.new(**{})
                if payable
                  self.context.payables= [payable]
                  self.currency ||= payable.try(:payable_currency)
                end
                self.context.currencies= [currency] if currency
              end
              before_validation do
                self.direction = self.class.direction
              end
              before_save do
                # self.payment_method_amount ||= self.amount
                self.payer ||= payment_method&.holder if charge?
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

            def define_state_alias_scopes
              state_machine(:state).states.each do |state_def|
                state_name = state_def.name
                scope state_name, -> { with_state(state_name) } unless respond_to?(state_name)
              end
            end

          end

          module Hooks
            extend ActiveSupport::Concern
            included do

              grape_api_resource 'payment_core', default: true do
                query_scope do |query_scope, api|
                  api.current_holder.payment_entries
                end
                presenter "PaymentCore::Grape::Presenters::Entry"
              end

              scope :with_entry_types, -> (*types) {
                types = ::PaymentCore::Entry.entry_types(*types).map(&:name)
                where(type: types)
              }

              scope :with_directions, -> (*args) {
                types = ::PaymentCore::Entry.directions(*args).map(&:name)
                where(type: types)
              }

              with_options unless: :wrapper? do
                validates :payment_method, presence: true
                validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0, allow_blank: true }
                validates :currency, presence: true
              end
              with_options if: :payment_method do
                validate do
                  entry_type = self.class.entry_type
                  unless payment_method.class.allowed_entry_types.include?(entry_type)
                    errors.add(:payment_method, :entry_type_not_allowed)
                  end
                end
                validates :payment_method_amount, presence: true, numericality: { greater_than_or_equal_to: 0, allow_blank: true }
              end
              with_options if: :parent do
                validate do
                  errors.add(:parent, :not_wrapper) unless parent.wrapper?
                end
                after_save do
                  parent.success if parent.wrapper? #&& parent.may_success?
                end
              end
              with_options if: proc {|record| !record.partial && record.payable } do
                validate do
                  if amount < unpaid_amount
                    errors.add(:amount, :insufficient_amount)
                  end
                end
              end
              with_options if: :payable do
                validate on: :create do
                  if payable.payable_status == "paid"
                    errors.add(:amount, :already_paid)
                  end
                end
              end
            end

            module ClassMethods
              def inherited(subclass)
                super(subclass)
                subclass.entry_type= subclass.name.demodulize.underscore
                ::PaymentCore::Models::Decorators::Entry::Object << subclass
                # after_class_defined(subclass) do
                # end
              end
            end
          end

          module RelationHooks
            extend ActiveSupport::Concern

            included do

              acts_as_paranoid if ::PaymentCore.config.soft_delete_enabled

              if paranoid?
                belongs_to :parent, -> { with_deleted }, class_name: 'PaymentCore::Entry', foreign_key: 'parent_id', optional: true
                has_many :components, -> { with_deleted }, class_name: 'PaymentCore::Entry', foreign_key: 'parent_id', dependent: :destroy
              else
                belongs_to :parent, class_name: 'PaymentCore::Entry', foreign_key: 'parent_id', optional: true
                has_many :components, class_name: 'PaymentCore::Entry', foreign_key: 'parent_id', dependent: :destroy
              end
              belongs_to :payable, polymorphic: true, optional: true
              belongs_to :payer, polymorphic: true, optional: true
              belongs_to :paid_at, polymorphic: true, optional: true
              belongs_to :reference, polymorphic: true, optional: true

              accepts_nested_attributes_for :components, reject_if: :all_blank

            end

            module ClassMethods
              def inherited subclass
                super(subclass)
                after_class_defined(subclass) do
                  ::PaymentCore::Models::Decorators::Payable.payable_classes.each do |payable_class|
                    payable_class.payable_setup do
                      define_payable_entry_relation(subclass)
                    end
                  end
                  ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes.each do |klass|
                    klass.setup do
                      define_entry_relation(subclass)
                    end
                  end
                  ::PaymentCore::Models::Decorators::PaymentIntent::Object.registered_classes.each do |klass|
                    klass.setup do
                      define_entry_relation(subclass)
                    end
                  end
                  ::PaymentCore::Models::Decorators::PaymentMethodHolder.registered_classes.each do |klass|
                    klass.payment_method_holder_setup do
                      define_payment_method_holder_entry_relation(subclass)
                    end
                  end
                end
              end

              def entry_relation_name_on_payment_method
                if self == base_class
                  :entries
                else
                  "entry_#{name.demodulize.underscore.pluralize}".to_sym
                end
              end

              def entry_relation_name_on_payable
                if self == base_class
                  :payable_entries
                else
                  "payable_#{name.demodulize.underscore}_entries".to_sym
                end
              end

              def entry_relation_name_on_payment_intent
                if self == base_class
                  :entries
                else
                  "entry_#{name.demodulize.underscore.pluralize}".to_sym
                end
              end

              def entry_relation_name_on_holder
                if self == base_class
                  :payment_entries
                else
                  "payment_#{name.demodulize.underscore}_entries".to_sym
                end
              end

              private

              def define_payment_method_relations
                ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes.each do |klass|
                  define_payment_method_relation(klass)
                end
              end

              def define_payment_method_relation(klass = ::PaymentCore::PaymentMethod)
                assoc_name = klass.payment_method_relation_name_on_entry
                unless reflect_on_association(assoc_name)
                  if paranoid?
                    belongs_to assoc_name, -> { with_deleted }, class_name: klass.name, foreign_key: 'payment_method_id', counter_cache: :entries_count, optional: true, inverse_of: :entries
                  else
                    belongs_to assoc_name, class_name: klass.name, foreign_key: :payment_method_id, optional: true, counter_cache: :entries_count, inverse_of: :entries
                  end
                end
              end

              def define_payment_intent_relations
                ::PaymentCore::Models::Decorators::PaymentIntent::Object.registered_classes.each do |klass|
                  define_payment_intent_relation(klass)
                end
              end

              def define_payment_intent_relation(klass= ::PaymentCore::PaymentIntent)
                assoc_name = klass.payment_intent_relation_name_on_entry
                unless reflect_on_association(assoc_name)
                  if paranoid?
                    belongs_to assoc_name, -> { with_deleted }, class_name: klass.name, foreign_key: 'payment_intent_id', optional: true
                  else
                    belongs_to assoc_name, class_name: klass.name, foreign_key: 'payment_intent_id', optional: true
                  end
                end
              end

            end

          end

          module InstanceMethods

            def unpaid_amount
              if metadata.try(:use_intent_amount) && payment_intent
                payment_intent.amount
              else
                payable.payable_unpaid_amount
              end
            end

            def metadata=(opts)
              if payment_method
                opts[:payment_method_type] = payment_method.class.method_type
              end
              super(opts)
            end

            def payment_method=(value)
              super(value)
            end

            def component?
              parent_id.present?
            end

            def method_missing(name, *args, &block)
              self.class.method_missing(name, *args, &block)
            end

          end

        end
      end
    end
  end
end
