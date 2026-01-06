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
            base.include RelationHooks

            base.eventable_bus_name = base.name.demodulize.underscore.to_sym

            base.inheritable_class_attribute :entry_type, :direction
            base.entry_type= base.name.demodulize.underscore

            base.setup do
              register_default_callbacks
              register_cycle_events
              register_state_events
              register_state_method_helpers
              define_payment_method_relations
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
            end
          end

          module StateHooks
            extend ActiveSupport::Concern

            included do
              # | Entry Direction| Allowed States                                                        | Notes                             |
              # | -------------- | --------------------------------------------------------------------- | --------------------------------- |
              # | **payment**    | `pending`, `processing`, `succeeded`, `failed`, `canceled`, `expired` | Most common stateful process      |
              # | **refund**     | `pending`, `processing`, `succeeded`, `failed`                        | No `expired`, rarely `canceled`   |
              # | **deposit**    | `succeeded`, `failed`, `pending`, `processing`                        | Often manually marked `succeeded` |
              # | **withdraw**   | `pending`, `processing`, `succeeded`, `failed`, `canceled`            | Typically async to a bank         |
              # | **transfer**   | `succeeded`, `failed`, `processing`                                   | Can be instantaneous or queued    |
              # | **adjustment** | `succeeded`, `failed`                                                 | Usually a one-time admin op       |
              # | **wrapper**    | `pending`, `succeeded`, `failed`                                  | for wrapper                       |
              enum state: {
                pending:       'pending',       # created, awaiting action
                processing:    'processing',    # in progress, may resolve async
                succeeded:     'succeeded',     # completed successfully
                failed:        'failed',        # terminal error
                canceled:      'canceled',      # intentionally voided
                expired:       'expired',       # timed out / no longer valid
                reversed:      'reversed',      # undone after success (rare)
                disputed:      'disputed',      # challenged by customer (card, etc)
              }#, _prefix: :state

              states.keys.each do |state_name|
                define_method state_name do
                  self.state = state_name
                end
              end

            end
          end

          module ClassMethods

            def wrap(entries=[], params={}, &block)
              result =
              if block_given?
                wrapper = PaymentCore::Entries::Wrapper.new(params)
                wrapper.pending
                wrapper.idempotency_lock!(window: 5.seconds) do
                  begin
                    if wrapper.process!
                      entries.each_with_index do |entry, i|
                        yield(entry, wrapper)
                        wrapper.components << entry
                        wrapper = entry.parent
                        entry.errors.each {|e| wrapper.errors.import e, **e.options.merge(attribute: "components.#{i}.#{e.attribute}")}
                      end
                    end
                    wrapper.success! unless wrapper.succeeded?
                    raise ActiveRecord::Rollback if wrapper.errors.any?
                  rescue => e
                    wrapper.errors.add(:base, e.message) unless wrapper.errors.any?
                    raise ActiveRecord::Rollback, e.message
                  end
                end
                wrapper
              end
              result = if result.nil?
                result = self.class.new
                result.errors.add(:id, :invalid)
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
                self.state ||= "pending"
              end
              before_save do
                # self.payment_method_amount ||= self.amount
                self.payer ||= payment_method&.holder if charge?
              end
            end

            def register_state_method_helpers
              states.each do |k,v|
                define_method "after_state_#{k}?" do
                  saved_change_to_state? && state == k
                end
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
                    errors.add(:payment_method, :invalid)
                  end
                end
                validates :payment_method_amount, presence: true, numericality: { greater_than_or_equal_to: 0, allow_blank: true }
              end
              with_options if: :parent do
                validate do
                  errors.add(:parent, :invalid) unless parent.wrapper?
                end
                after_save do
                  parent.success! if parent.may_success?
                end
              end
              with_options if: proc {|record| !record.partial && record.payable } do
                validate do
                  if amount < payable.payable_unpaid_amount
                    errors.add(:amount, :invalid)
                  end
                end
              end
              with_options if: :payable do
                validate on: :create do
                  if payable.payable_status == "paid"
                    errors.add(:amount, "paid")
                  end
                end
              end

              def self.inherited(subclass)
                super(subclass)
                subclass.entry_type= subclass.name.demodulize.underscore
                after_class_defined(subclass) do
                  ::PaymentCore::Models::Decorators::Entry::Object << subclass
                end
              end
            end
          end

          module RelationHooks
            extend ActiveSupport::Concern

            included do

              acts_as_paranoid if ::PaymentCore.config.soft_delete_enabled

              if paranoid?
                #belongs_to :payment_intent, -> { with_deleted }, class_name: "PaymentCore::PaymentIntent", foreign_key: 'payment_intent_id', optional: true
                belongs_to :parent, -> { with_deleted }, class_name: 'PaymentCore::Entry', foreign_key: 'parent_id', optional: true
                has_many :components, -> { with_deleted }, class_name: 'PaymentCore::Entry', foreign_key: 'parent_id', dependent: :destroy
              else
                #belongs_to :payment_intent, class_name: "PaymentCore::PaymentIntent", foreign_key: 'payment_intent_id', optional: true
                belongs_to :parent, class_name: 'PaymentCore::Entry', foreign_key: 'parent_id', optional: true
                has_many :components, class_name: 'PaymentCore::Entry', foreign_key: 'parent_id', dependent: :destroy
              end
              belongs_to :payable, polymorphic: true, optional: true
              belongs_to :payer, polymorphic: true, optional: true
              belongs_to :paid_at, polymorphic: true, optional: true
              belongs_to :reference, polymorphic: true, optional: true

              accepts_nested_attributes_for :components, reject_if: :all_blank

              extend ClassMethods

              module ClassMethods
                def inherited subclass
                  super(subclass)
                  after_class_defined(subclass) do
                    ::PaymentCore.decorators.payable.payable_classes.each do |payable_class|
                      payable_class.define_payable_entry_subclass_relation(subclass)
                    end
                    ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes.each do |klass|
                      klass.setup do
                        define_entry_relation(subclass)
                      end
                    end
                    # ::PaymentCore::Models::Decorators::Payable.registered_classes.each do |klass|
                    #   klass.payable_setup do
                    #     define_payable_entry_relation(subclass)
                    #   end
                    # end
                  end
                end
              end

            end

            class_methods do
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
            end

          end

          module InstanceMethods

            def metadata=(opts)
              if payment_method
                opts[:payment_method_type] = payment_method.class.method_type
              end
              super(opts)
            end

            def component?
              parent_id.present?
            end

            def success!
              self.succeeded_at= Time.current
              succeeded!
            end

            def process!
              self.processed_at= Time.current
              processing!
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
