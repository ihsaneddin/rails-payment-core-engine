require 'set'

module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module Object

          mattr_accessor :registered_classes
          mattr_accessor :registered_traits
          @@registered_classes = Set.new
          @@registered_traits  = Set.new

          def self.register_class klass
            @@registered_classes << klass
          end

          def self.register_trait mod
            @@registered_traits << mod
          end

          def self.included(base)
            unless base <= ::PaymentCore::PaymentMethod
              raise "Invalid : #{base.name} is not a PaymentCore::PaymentMethod class"
            end

            base.extend ClassMethods
            base.include ::Plugins::Models::Concerns::CustomAttributes
            base.include ::Plugins::Models::Concerns::PolymorphicAlternative
            base.include ::Plugins::Models::Concerns::Eventable::PublishesEvents
            base.include ::Plugins::Models::Concerns::RemoteCallbacks
            base.include ::Plugins::Models::Concerns::ApiResource
            base.include ::Plugins.decorators.method_annotations
            base.include ::Plugins.decorators.method_decorators
            base.include ::Plugins.decorators.inheritables.singleton_methods

            base.inheritable_class_attribute :method_type, :method_name, :allowed_entry_types, :direction, :requires_payable
            base.class_attribute :registered_names, default: {}
            base.set_method_type
            base.set_method_name
            base.allowed_entry_types = Set.new(['charge'])
            base.direction = :credit

            base.custom_attributes_definition :metadata,
                                              ::PaymentCore.config.payment_method.metadata_base_class_constant, accessor: true
            base.custom_attributes_definition :availability_rules,
                                              ::PaymentCore.config.payment_method.availability_rules_class_constant, accessor: false

            base.define_method_decorator :reference_payment_method_decorator do |method_name, original, *args, block, **_opts|
              if use_reference && reference && reference.payment_method_reference_functions.exists?(method_name.to_sym)
                reference.payment_method_reference_functions.send(method_name, *args)
              else
                original.call(*args, &block)
              end
            end

            base.define_inheritable_singleton_method :reference_payment_method do |method_name, &fallback|
              define_method(method_name, &fallback) if fallback
              annotate_method(method_name, reference_method: true)
              decorate_method(method_name, with: :reference_payment_method_decorator)
            end

            base.define_inheritable_singleton_method :entry_callback do |*args, &block|
              opts = args.extract_options!
              callback_name = args[0]
              method_name = args[1]
              opts = { source: :payment_method, if: true, exclusive: false }.merge(opts)
              callback_for(::PaymentCore::Entry, callback_name, method_name, opts, &block)
              # ::PaymentCore::Entry.descendants.each do |subclass|
              #   subclass.callback_for(callback_name, method_name, opts, &block)
              # end
            end

            base.before_save do
              self.method_type = self.class.method_type
            end

            base.entry_callback :validate do |entry|
              entry.errors.add(:payment_method, 'Not available') unless available?(context: entry.context)
            end

            base.entry_callback :validate, if: proc { payment_method && payment_method.requires_payable? } do |entry|
              entry.errors.add(:payable, :required) unless entry.payable.present?
            end

            base.entry_callback(:validate) do |entry|
              entry.errors.add(:payment_method, :invalid) unless self.class.allows_entry_type?(entry.class.entry_type)
            end

            base.entry_callback(:after_save) do |entry|
              entry.payment_method.update_column(:last_used_at, DateTime.now) if entry.payment_method
            end

            base.include InstanceMethods
            register_class(base)
            registered_traits.each do |trait|
              include_trait_class_methods(base, trait)
            end
          end

          def self.extended(trait_mod)
            register_trait(trait_mod)

            registered_classes.each do |klass|
              include_trait_class_methods(klass, trait_mod)
              define_trait_flag_methods(klass, trait_mod)
            end
          end

          def self.include_trait_class_methods(klass, trait)
            klass.extend trait.const_get(:ClassMethods) if trait.const_defined?(:ClassMethods)
          end

          def self.define_trait_flag_methods(klass, trait)
            trait_name = if trait.respond_to?(:trait_name)
                           trait.trait_name.to_s
                         else
                           trait.name.demodulize.underscore
                         end

            method_name = "#{trait_name}?"

            ::PaymentCore::Models::Decorators::PaymentMethod.define_inheritable_singleton_method trait_name do
              trait
            end

            ::PaymentCore::Models::Decorators::PaymentMethod.define_inheritable_singleton_method "#{trait_name}_object" do
              trait.const_get(:InstanceMethods)
            end

            klass.define_inheritable_singleton_method(method_name) { false } unless klass.respond_to?(method_name)

            unless klass.method_defined?(method_name)
              klass.define_method(method_name) do
                self.class.send(method_name)
              end
            end
          end

          module ClassMethods
            def inherited(subclass)
              super(subclass)
              ::PaymentCore::Models::Decorators::PaymentMethod::Object.register_class(subclass)
              subclass.set_method_name
              subclass.set_method_type
              mname = subclass.method_name
              base = self
              base_class.define_method "#{mname}?" do
                self.class.method_name == mname
              end
              base_class.define_method "kind_of_#{mname}?" do
                self.class <= base
              end
            end

            def requires_payable!
              self.requires_payable= true
            end

            def requires_payable?
              self.requires_payable
            end

            def set_registered_name(type, klass)
              registered_names[type.to_sym] = klass
            end

            def set_method_type(mname = 'cash')
              self.method_type = mname
            end

            def set_method_name(mname = name.demodulize.underscore)
              set_registered_name(mname, self)
              self.method_name = mname
            end

            def allowed_entry_types
              allowed_entry_types.presence || Set.new(['charge'])
            end

            def allows_entry_type(entry_type)
              # if ::PaymentCore::Entry.descendants.map(&:entry_type).include?(entry_type.to_s)
              self.allowed_entry_types += [entry_type]
              # else
              #   raise "Unknown entry name for #{entry_type}"
              # end
            end

            def allows_entry_type?(entry_type)
              allowed_entry_types.include?(entry_type.to_s)
            end

            def find_by_payment_method_name(pname)
              ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes.select { |sub| sub.method_name.to_s == pname.to_s }[0]
              #base_class.descendants.select { |sub| sub.method_name.to_s == pname.to_s }[0]
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

          end

          module InstanceMethods
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
              @processor ||= ::PaymentCore.config.payment_processor_registry.resolve(self.method_type).new(self, **{ context: context, payer: payer })
            end

            def requires_payable?
              self.class.requires_payable?
            end

          end
        end
      end
    end
  end
end
