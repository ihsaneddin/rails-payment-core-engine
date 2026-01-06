module PaymentCore
  module Models
    module Decorators
      module PaymentMethodReference
        mattr_accessor :reference_classes
        @@reference_classes = Set.new

        def self.<<(klass)
          @@reference_classes << klass #unless @@reference_classes.include?(klass)
        end

        def self.included(base)
          base.include ::Plugins.decorators.inheritables
          method_name = :payment_method_reference?
          base.define_inheritable_singleton_method(method_name) { false } unless base.respond_to?(method_name)

          unless base.method_defined?(method_name)
            base.define_method(method_name) do
              self.class.send(method_name)
            end
          end

          base.extend ClassMethods
        end

        def self.default_options
          {
            attributes: {},
            functions: ::Plugins::Models::Concerns::Config.build,
            sync_attributes: 'none', # options are none, async, sync
            type: proc {
              payment_method_reference_payment_method_class.constantize
            },
            payment_method_class: nil
          }
        end

        module ClassMethods
          def payment_method_reference(*args, &block)
            #return unless ::ActiveRecord::Base.connection.table_exists?('payment_core_payment_methods')

            payment_method_type = args[0] || 'cash'
            opts = args.extract_options!

            payment_method_class = ::PaymentCore::PaymentMethod.find_by_payment_method_type(payment_method_type)
            payment_method_class ||= payment_method_type.constantize rescue nil

            raise "Payment method of #{payment_method_type} not found" if payment_method_class.nil?

            functions = payment_method_class.methods_annotated_with(:reference_method, true)
            functions = payment_method_class.descendants.inject(functions) do |fs, subclass|
              fs + subclass.methods_annotated_with(:reference_method, true)
            end

            functions = functions.to_h do |k|
              value = proc {
                mname = self.class.payment_method_for(k.to_sym)
                send(mname) if mname
              }
              [k, value]
            end

            opts[:functions] = ::Plugins::Models::Concerns::Config.build(**functions)
            opts[:payment_method_class] = payment_method_class.name

            default_opts = ::PaymentCore.decorators.payment_method_reference.default_options
            ::Plugins::Models::Concerns::Config.setup(self, 'payment_method_reference_config', opts, default_opts,
                                                      method_prefix: 'payment_method_reference', &block)

            unless reflect_on_association(:payment_method)
              has_one :payment_method, class_name: payment_method_class.name, as: :reference
              assoc_name = "payment_method_reference_of_#{base_class.name.demodulize.underscore}"
              ::PaymentCore::PaymentMethod.define_alternative_polymorphic_parent_association assoc: :reference,
                                                                                             new_assoc: assoc_name, base_class: base_class
            end

            include ::Plugins.decorators.method_annotations

            define_inheritable_singleton_method :payment_method_availability do |method_name = nil, method_types: :all, &block|
              method_name ||= :"payment_method_availability_#{SecureRandom.hex(8)}"
              annotate_method(method_name, payment_method_availability: true, method_types: method_types, &block)
            end

            define_inheritable_singleton_method :payment_method do |method_name, payment_method_type, &block|
              annotate_method(method_name, payment_method: payment_method_type, &block)
            end

            define_inheritable_singleton_method :payment_method_for do |payment_method_type|
              methods_annotated_with(:payment_method, payment_method_type)[0]
            end

            define_inheritable_singleton_method(:payment_method_reference?) { true }
            include InstanceMethods
            include InheritableHook
            include ::Plugins::Models::Concerns::ApiResource unless include?(::Plugins::Models::Concerns::ApiResource)

            grape_api_resource "payment_core", default: true do
              presenter "PaymentCore::Grape::Presenters::PaymentMethodReference"
            end

            ::PaymentCore.decorators.payment_method_reference << self
          end
        end

        module InheritableHook
          extend ActiveSupport::Concern

          included do
            class << self
              def inherited(subclass)
                super(subclass)
                ::PaymentCore.decorators.payment_method_reference << subclass
              end
            end
          end
        end

        module InstanceMethods
          def payment_method_attributes
            payment_method_reference_attributes
          end

          def payment_method_functions
            payment_method_reference_functions
          end

          def payment_method_type
            unless payment_method_reference_type <= payment_method_reference_payment_method_class.constantize
              raise "Invalid class : #{payment_method_reference_type.name} is not #{payment_method_reference_payment_method_class} nor its subclass"
            end
            payment_method_reference_type
          end

          def create_payment_method_as_reference
            create_payment_method({ use_reference: true, reference: self, type: payment_method_reference_type.name })
          end
        end

        module SyncCallbacks
          extend ActiveSupport::Concern

          included do
            attr_accessor :payment_method_attributes

            with_options if: :payment_method do
              after_initialize :set_payment_method_attributes

              after_commit if: :payment_method_attributes_changes? do
                if payment_method_reference_config.sync_data == 'sync'
                  sync_payment_method
                elsif payment_method_reference_config.sync_data == 'async'
                  PaymentCore::PaymentMethodReferenceWorker.perform_at(DateTime.now, nil, 'attributes_sync',
                                                                       self.class.name, id)
                end
                set_payment_method_attributes
              end
            end
          end

          def set_payment_method_attributes
            self.payment_method_attributes = payment_method_reference_attributes
          end

          def payment_method_attributes_changes?
            current_payment_method_attributes = payment_method_reference_attributes
            !Hashdiff.diff(current_payment_method_attributes, payment_method_attributes).empty?
          end

          def sync_payment_method
            if payment_method && payment_method.uses_reference? && payment_method.use_reference
              payment_method.sync_payment_method_reference_attributes
            end
          end
        end
      end
    end
  end
end
