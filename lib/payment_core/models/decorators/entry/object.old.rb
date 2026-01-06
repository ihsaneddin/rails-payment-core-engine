# module PaymentCore
#   module Models
#     module Decorators
#       module Entry
#         module Object

#           mattr_accessor :registered_classes
#           self.registered_classes = Set.new

#           def self.register_class klass
#             @@registered_classes << klass
#           end

#           mattr_accessor :registered_directions
#           @@registered_directions  = Set.new

#           def self.register_direction mod
#             @@registered_directions << mod
#           end

#           mattr_accessor :registered_entry_types
#           @@registered_entry_types  = Set.new

#           def self.register_entry_type type
#             @@registered_entry_types << type
#           end

#           def self.included base
#             base.include ::Plugins::Models::Concerns::PolymorphicAlternative
#             base.include ::Plugins::Models::Concerns::Eventable::PublishesEvents
#             base.include ::Plugins::Models::Concerns::CustomAttributes
#             base.include ::Plugins::Models::Concerns::RemoteCallbacks
#             base.include ::Plugins::Models::Concerns::ApiResource
#             base.include ::Plugins::Models::Concerns::IdempotencyLockable
#             base.include ::Plugins::Models::Concerns::ThreadSafe
#             base.include ::Plugins::Models::Concerns::TracksTransactionRoot
#             base.include ::Plugins.decorators.inheritables.class_attributes
#             base.extend ClassMethods

#             base.inheritable_class_attribute :entry_type, :direction
#             base.set_entry_type

#             base.eventable_bus_name = base.name.demodulize.underscore.to_sym

#             base.enum state: {
#               pending:       'pending',       # created, awaiting action
#               processing:    'processing',    # in progress, may resolve async
#               succeeded:     'succeeded',     # completed successfully
#               failed:        'failed',        # terminal error
#               canceled:      'canceled',      # intentionally voided
#               expired:       'expired',       # timed out / no longer valid
#               reversed:      'reversed',      # undone after success (rare)
#               disputed:      'disputed',      # challenged by customer (card, etc)
#             }#, _prefix: :state

#             base.states.keys.each do |state_name|
#               base.define_method state_name do
#                 self.state = state_name
#               end
#             end

#             # | Entry Direction| Allowed States                                                        | Notes                             |
#             # | -------------- | --------------------------------------------------------------------- | --------------------------------- |
#             # | **payment**    | `pending`, `processing`, `succeeded`, `failed`, `canceled`, `expired` | Most common stateful process      |
#             # | **refund**     | `pending`, `processing`, `succeeded`, `failed`                        | No `expired`, rarely `canceled`   |
#             # | **deposit**    | `succeeded`, `failed`, `pending`, `processing`                        | Often manually marked `succeeded` |
#             # | **withdraw**   | `pending`, `processing`, `succeeded`, `failed`, `canceled`            | Typically async to a bank         |
#             # | **transfer**   | `succeeded`, `failed`, `processing`                                   | Can be instantaneous or queued    |
#             # | **adjustment** | `succeeded`, `failed`                                                 | Usually a one-time admin op       |
#             # | **wrapper**    | `pending`, `succeeded`, `failed`                                  | for wrapper                       |


#             # core setup
#             base.custom_attributes_definition :metadata, ::PaymentCore.config.payment_entry.metadata_base_class_constant, accessor: true

#             base.register_default_callbacks
#             base.register_cycle_events
#             base.register_state_events

#             tracer = TracePoint.new(:end) do |tp|
#               if tp.self == base
#                 base.register_state_method_helpers
#                 tracer.disable
#               end
#             end
#             tracer.enable

#             base.attr_accessor :context

#             base.include InstanceMethods
#           end

#           def self.extended(direction_mod)
#             register_direction(direction_mod)

#             registered_classes.each do |klass|
#               include_direction_class_methods(klass, direction_mod)
#               define_direction_flag_methods(klass, direction_mod)
#             end
#           end

#           def self.include_direction_class_methods(klass, direction)
#             klass.extend direction.const_get(:ClassMethods) if direction.const_defined?(:ClassMethods)
#           end

#           def self.define_direction_flag_methods(klass, direction)
#             direction_name = if direction.respond_to?(:direction_name)
#                            direction.direction_name.to_s
#                          else
#                            direction.name.demodulize.underscore
#                          end

#             method_name = "#{direction_name}?"

#             ::PaymentCore::Models::Decorators::Entry.define_inheritable_singleton_method direction_name do
#               direction
#             end

#             ::PaymentCore::Models::Decorators::Entry.define_inheritable_singleton_method "#{direction_name}_object" do
#               direction.const_get(:InstanceMethods)
#             end

#             klass.define_inheritable_singleton_method(method_name) { false } unless klass.respond_to?(method_name)

#             unless klass.method_defined?(method_name)
#               klass.define_method(method_name) do
#                 self.class.send(method_name)
#               end
#             end
#           end

#           module ClassMethods

#             def inherited(subclass)
#               super(subclass)
#               subclass.set_entry_type
#               unless ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.map(&:entry_type).include?(subclass.entry_type)
#                 #raise ArgumentError, "Duplicate entry_type '#{name}' detected for #{subclass}"
#                 ::PaymentCore::Models::Decorators::Entry::Object.register_entry_type(subclass.entry_type)
#               end
#               ::PaymentCore::Models::Decorators::Entry::Object.register_class(subclass)
#               ::PaymentCore.decorators.payable.payable_classes.each do |payable_class|
#                 payable_class.define_payable_entry_subclass_relation(subclass)
#               end
#               curr_entry_type = subclass.entry_type
#               base_class.define_method("#{curr_entry_type}?".to_sym) do
#                 self.class.entry_type.to_s == curr_entry_type.to_s
#               end
#               tracer = TracePoint.new(:end) do |tp|
#                 if tp.self == subclass
#                   subclass.register_state_method_helpers
#                   tracer.disable
#                 end
#               end
#               tracer.enable
#             end

#             def directions *args
#               ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.select{|sub| args.map(&:to_s).include?(sub.direction) }
#             end

#             def entry_types *args
#                ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.select{|sub| args.map(&:to_s).include?(sub.entry_type) }
#             end

#             def set_entry_type(ename = nil)
#               self.entry_type = ename || name.demodulize.underscore
#             end

#             def register_state_events
#               after_commit do
#                 if state.present? && state != state_before_last_save
#                   publish_event("state.#{state}")
#                 end
#               end
#             end

#             def register_cycle_events
#               after_commit on: :create do
#                 publish_event(:created)
#               end
#               after_commit on: :update do
#                 publish_event(:updated)
#               end
#               after_commit on: :destroy do
#                 publish_event(:deleted)
#               end
#             end

#             def register_default_callbacks
#               before_validation do |entry|
#                 self.context ||= ::PaymentCore.config.payment_method.availability_context_class_constant.new(**{})
#                 if payable
#                   self.context.payables= [payable]
#                   self.currency ||= payable.try(:payable_currency)
#                 end
#                 self.context.currencies= [currency] if currency
#               end
#               before_validation do
#                 self.direction = self.class.direction
#                 self.state ||= "pending"
#               end
#               before_save do
#                 # self.payment_method_amount ||= self.amount
#                 self.payer ||= payment_method&.holder if charge?
#               end
#             end

#             def register_state_method_helpers
#               states.each do |k,v|
#                 define_method "after_state_#{k}?" do
#                   saved_change_to_state? && state == k
#                 end
#               end
#             end

#             def method_missing(name, *args, &block)
#               registered_entry_types = ::PaymentCore::Models::Decorators::Entry::Object.registered_entry_types
#               registered_entry_types = registered_entry_types.to_a.map{|type| "#{type}?" }
#               if registered_entry_types.include?(name.to_s)
#                 "#{self.entry_type}?" == name.to_s
#               else
#                 super(name, *args, &block)
#               end
#             end

#           end

#           module InstanceMethods

#             def metadata=(opts)
#               if payment_method
#                 opts[:payment_method_type] = payment_method.class.method_type
#               end
#               super(opts)
#             end

#             def component?
#               parent_id.present?
#             end

#             def success!
#               self.succeeded_at= Time.current
#               succeeded!
#             end

#             def process!
#               self.processed_at= Time.current
#               processing!
#             end

#             def method_missing(name, *args, &block)
#               registered_entry_types = ::PaymentCore::Models::Decorators::Entry::Object.registered_entry_types
#               registered_entry_types = registered_entry_types.to_a.map{|type| "#{type}?" }
#               if registered_entry_types.include?(name.to_s)
#                 "#{self.class.entry_type}?" == name.to_s
#               else
#                 super(name, *args, &block)
#               end
#             end

#           end

#         end
#       end
#     end
#   end
# end
