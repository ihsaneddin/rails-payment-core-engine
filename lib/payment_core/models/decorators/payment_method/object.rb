module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module Object

          include ::Plugins.decorators.traits

          def invalid_class?(base)
            unless base.include?(::PaymentCore::Models::Decorators::PaymentMethod::Object)
              raise "Invalid : #{base.name} does not include #{::PaymentCore::Models::Decorators::PaymentMethod::Object} module"
            end
          end

          def self.registered_classes
            if @@registered_classes.blank?
              @@registered_classes << ::PaymentCore::PaymentMethod
            end
            @@registered_classes
          end

          def self.registered_method_types
            registered_classes.map(&:method_type)
          end

          def self.included(base)
            unless base <= ::PaymentCore::PaymentMethod
              raise "Invalid : #{base.name} is not a PaymentCore::PaymentMethod class"
            end

             base.include DepedencyHooks
             base.extend ClassMethods
             base.include RelationHooks
             base.extend RelationHooks::ClassMethods
             base.include Hooks
             base.extend Hooks::ClassMethods

             base.inheritable_class_attribute :method_type, :allowed_entry_types, :direction, :requires_payable, :entry_method_data_defaults_config
             base.method_type = base.name.demodulize.underscore
             base.eventable_bus_name = base.name.demodulize.underscore.to_sym
             base.allowed_entry_types = Set.new(['charge'])
             base.direction = :credit
             base.entry_method_data_defaults_config = nil

             base.setup do
               define_metadata_class
               define_availability_rules_class
               define_entry_relations
               register_cycle_events
             end

             base.include InstanceMethods
             ::PaymentCore::Models::Decorators::PaymentMethod::Object << base
             super(base) if defined?(super)

          end

          module DepedencyHooks
            extend ActiveSupport::Concern

            included do
              include ::Plugins::Models::Concerns::CustomAttributes
              include ::Plugins::Models::Concerns::PolymorphicAlternative
              include ::Plugins::Models::Concerns::Eventable::PublishesEvents
              include ::Plugins::Models::Concerns::RemoteCallbacks
              include ::Plugins::Models::Concerns::ApiResource
              include ::Plugins.decorators.method_annotations
              include ::Plugins.decorators.method_decorators
              include ::Plugins.decorators.inheritables.singleton_methods
              include ::Plugins.decorators.hooks
              include ::Plugins::EngineCallbacks
              extend ::PaymentCore::Models::Decorators::Core
            end
          end

          module ClassMethods

            def requires_payable!
              self.requires_payable= true
            end

            def requires_payable?
              self.requires_payable
            end

            def allowed_entry_types
              allowed_entry_types.presence || Set.new(['charge'])
            end

            def allows_entry_type(entry_type)
              self.allowed_entry_types += [entry_type]
            end

            def remove_allowed_entry_type(entry_type)
              self.allowed_entry_types -= [entry_type]
            end

            def allows_entry_type?(entry_type)
              allowed_entry_types.include?(entry_type.to_s)
            end

            def find_by_payment_method_type(pname)
              ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes.select { |sub| sub.method_type.to_s == pname.to_s }[0]
            end

            def idempotency_key_fields
              Proc.new{
                if payer
                  [:payer_type, :payer_id]
                else
                  [:id]
                end
              }
            end

            def entry_method_data_defaults(value = nil, &block)
              if block_given? || !value.nil?
                self.entry_method_data_defaults_config = block_given? ? block : value
              end
              entry_method_data_defaults_config
            end

            def setup &block
              instance_exec(&block) if block_given?
            end

            private

            def define_metadata_class(klass= ::PaymentCore.config.payment_method.metadata_base_class_constant)
              custom_attributes_definition :metadata, klass, accessor: true
            end

            def define_availability_rules_class(klass= ::PaymentCore.config.payment_method.availability_rules_class_constant)
              custom_attributes_definition :availability_rules, klass, accessor: false
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

          end

          module Hooks
            extend ActiveSupport::Concern
            included do

              define_method_decorator :reference_payment_method_decorator do |method_name, original, *args, block, **_opts|
                if use_reference && reference && reference.payment_method_reference_functions.exists?(method_name.to_sym)
                  reference.payment_method_reference_functions.send(method_name, *args)
                else
                  original.call(*args, &block)
                end
              end

              define_inheritable_singleton_method :reference_payment_method do |method_name, &fallback|
                define_method(method_name, &fallback) if fallback
                annotate_method(method_name, reference_method: true)
                decorate_method(method_name, with: :reference_payment_method_decorator)
              end

              define_inheritable_singleton_method :entry_callback do |*args, &block|
                opts = args.extract_options!
                callback_name = args[0]
                method_name = args[1]
                opts = { source: :payment_method, if: true, exclusive: false }.merge(opts)
                ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.each do |klass|
                  callback_for(klass, callback_name, method_name, opts, &block)
                end
              end

              before_save do
                self.method_type = self.class.method_type
              end

              entry_callback :validate do |entry|
                entry.errors.add(:payment_method, :unavailable) unless available?(context: entry.context)
              end

              entry_callback :validate, if: proc { payment_method && payment_method.requires_payable? } do |entry|
                entry.errors.add(:payable, :required) unless entry.payable.present?
              end

              entry_callback(:validate) do |entry|
                entry.errors.add(:payment_method, :entry_type_not_allowed) unless self.class.allows_entry_type?(entry.class.entry_type)
              end

              entry_callback(:after_save) do |entry|
                entry.payment_method.update_column(:last_used_at, DateTime.now) if entry.payment_method
              end

              validate do
                if holder.present? && !holder.payment_method_holder?
                  errors.add(:holder, :invalid)
                end
              end

              after_payment_core_initialization do
                default_payment_methods_builder = ::PaymentCore.config.payment_method.default_payment_methods_builder
                if default_payment_methods_builder && default_payment_methods_builder.is_a?(Proc)
                  if ::ActiveRecord::Base.connection.table_exists?('payment_core_payment_methods')
                    instance_exec(&default_payment_methods_builder)
                  end
                end
              end
              grape_api_resource "payment_core", default: true do
                query_scope do |query_scope, api|
                  #api.current_holder.payment_method_candidates
                  if api.route.options[:action_name] == "update"
                    api.current_holder.payment_methods
                  else
                    api.current_holder.payment_method_candidates
                  end
                end
                resource_params_attributes do
                  [
                    :label_name, :active
                  ]
                end
                presenter "PaymentCore::Grape::Presenters::PaymentMethod"
              end

            end
            module ClassMethods
              def inherited(subclass)
                super(subclass)
                subclass.method_type= subclass.name.demodulize.underscore
                after_class_defined(subclass) do
                  ::PaymentCore::Models::Decorators::PaymentMethod::Object << subclass
                end
              end

            end
          end

          module RelationHooks
            extend ActiveSupport::Concern

            included do
              acts_as_paranoid if ::PaymentCore.config.soft_delete_enabled && !paranoid?

              belongs_to :holder, polymorphic: true, optional: true
              belongs_to :reference, polymorphic: true, optional: true

              scope :active, -> { where(active: true) }
              scope :default, -> { where(default: true) }
              scope :global, -> { where(holder: nil) }
              scope :always_available, -> { where(always_available: true) }

            end

            module ClassMethods
              def inherited(subclass)
                super(subclass)
                after_class_defined(subclass) do
                  ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.each do |klass|
                    klass.setup do
                      define_payment_method_relation(subclass)
                    end
                  end
                  ::PaymentCore::Models::Decorators::PaymentMethodHolder.registered_classes.each do |klass|
                    klass.payment_method_holder_setup do
                      define_payment_method_holder_payment_method_relation(subclass)
                    end
                  end
                end
              end

              def payment_method_relation_name_on_holder
                if self == base_class
                  :payment_methods
                else
                  "payment_method_#{self.name.demodulize.underscore.pluralize}".to_sym
                end
              end

              def payment_method_relation_name_on_entry
                if self == base_class
                  :payment_method
                else
                  "payment_method_#{self.name.demodulize.underscore}".to_sym
                end
              end

              def payment_method_relation_name_on_reference
                if self == base_class
                  :payment_method
                else
                  "payment_method_#{self.name.demodulize.underscore}".to_sym
                end
              end

              private

              def define_entry_relations
                ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.each do |klass|
                  define_entry_relation(klass)
                end
              end

              def define_entry_relation(klass= ::PaymentCore::Entry)
                assoc_name = klass.entry_relation_name_on_payment_method
                unless reflect_on_association(assoc_name)
                  scope = nil
                  unless klass == klass.base_class
                    scope = -> { where(type: klass.name) }
                  end
                  has_many(
                    assoc_name, scope,
                    class_name: klass.name, foreign_key: :payment_method_id, inverse_of: :payment_method,
                    extend: ::Plugins::Models::Extensions::Association::HasManyStiBuildersPatch.call(klass.name), dependent: :nullify
                  )
                end
              end
            end
          end

          module InstanceMethods

            def entry_method_data_defaults
              defaults = self.class.entry_method_data_defaults
              defaults = instance_exec(&defaults) if defaults.is_a?(Proc)
              defaults || {}
            end

            def method_missing(method_name, *args, &block)
              registered_types = ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_method_types.to_a.map{|type| "#{type}?" }
              if method_name.to_s.chomp("?") && registered_types.include?(method_name.to_s)
                if method_name.to_s == "kind_of_#{self.class.method_type}?"
                   self.class.super_class.method_type.to_s == self.class.method_type
                else
                  "#{self.class.method_type}?" == method_name.to_s
                end
              else
                super(method_name, *args, &block)
              end
            end

            def should_payment_method_be_available?(context, *args)
              availabilities = self.class.methods_annotated_with(:payment_method_availability, true).select{|mname| self.class.method_annotated_with?(mname, :method_types, :all) }
              availabilities = availabilities.concat(self.class.methods_annotated_with(:payment_method_availability, true).select{|mname| self.class.method_annotated_with?(mname, :method_types, payment_method.method_type.to_sym) })
              availability = availabilities.all? do |method_name|
                arguments = args.unshift(context)
                arguments = args.unshift(payment_method)
                avail = smart_send(method_name, arguments)
                avail.nil?? true : avail
              end
              always_available || (active && availability_rules.should_payment_method_be_available?(context, *args) && availability)
            end

            def available?(context: nil, holder: nil, payables: [])
              opts = { payment_method: self, context: context, holder: holder || self.holder, payables: payables }
              ::PaymentCore.config.payment_method.availabilty_matcher_class_constant.new(**opts).available?
            end

            def amount_available_for(payable, remaining_method_amount: nil)
              method_amount = nil
              if payable
                method_amount = payable.payable_payment_method_total_amount(self)
              end
              [method_amount, remaining_method_amount].compact.min
            end

            def processor(context: nil, payer: nil)
              @processor ||= custom_processor_class || ::PaymentCore.config.payment_processor_registry.resolve(self.method_type).new(self, **{ context: context, payer: payer })
            end

            def custom_processor_class
              metadata.processor_class ? metadata.processor_class.constantize : nil
            end

            def requires_payable?
              self.class.requires_payable?
            end

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
