module PaymentCore
  module Models
    module Decorators
      module PaymentMethodReference

        extend ::Plugins::Decorators::ConfigBuilder
        include ::Plugins.decorators.registered

        def self.included(base)
          base.extend ClassMethods
          base.define_method :payment_method_reference? do
            self.class.payment_method_reference?
          end
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
            ::PaymentCore.decorators.payment_method_reference.plugins_config.setup(self, 'payment_method_reference_config', opts, default_opts,
                                                      method_prefix: 'payment_method_reference', &block)

            include DepedencyHooks
            include Hooks
            extend Hooks::ClassMethods
            include RelationHooks
            extend RelationHooks::ClassMethods
            include PaymentMethodCallbacks

            payment_method_reference_setup do
              define_payment_method_relations
            end

            define_inheritable_singleton_method(:payment_method_reference?) { true }
            ::PaymentCore.decorators.payment_method_reference << self

            include InstanceMethods

          end

          def payment_method_reference?
            false
          end
        end

        module DepedencyHooks
          extend ActiveSupport::Concern
          included do
            include ::Plugins.decorators.method_annotations
            include ::Plugins.decorators.inheritables
            include ::Plugins.decorators.hooks
            include ::Plugins::Models::Concerns::ApiResource
          end
        end

        module Hooks
          extend ActiveSupport::Concern
          included do
            grape_api_resource "payment_core", default: true do
              presenter "PaymentCore::Grape::Presenters::PaymentMethodReference"
            end
          end
          module ClassMethods

            def inherited(subclass)
              super(subclass)
              after_class_defined(subclass) do
                ::PaymentCore::Models::Decorators::PaymentMethodReference << subclass
              end
            end

            def payment_method_reference_setup &block
              block_given? ? instance_exec(&block) : nil
            end

          end
        end

        module RelationHooks
          extend ActiveSupport::Concern

          included do

          end
          module ClassMethods

            private

            def define_payment_method_relations
              ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes.each do |klass|
                define_payment_method_relation(klass)
              end
            end

            def define_payment_method_relation(klass=::PaymentCore::PaymentMethod)
              assoc_name = klass.payment_method_relation_name_on_reference
              unless reflect_on_association(assoc_name)
                has_one assoc_name, class_name: klass.name, as: :reference
                klass.define_alternative_of_relation(self, relation: :reference)
              end
            end
          end
        end

        module PaymentMethodCallbacks
          extend ActiveSupport::Concern
          included do
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
