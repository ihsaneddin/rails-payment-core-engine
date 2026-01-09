module PaymentCore
  module Models
    module Decorators
      module PaymentMethodHolder

        extend ::Plugins::Decorators::ConfigBuilder
        include ::Plugins.decorators.registered

        def self.included(base)
          base.extend ClassMethods
          base.define_method :payment_method_holder? do
            self.class.payment_method_holder?
          end
        end

        def self.default_options
          {
            name: nil,
            email: nil,
            phone_number: nil,
            address: nil,
            default_payment_method: proc {
              payment_methods.active.find_by(default: true)
            },
            payment_method_candidates: proc {
              payment_methods.active.or(::PaymentCore::PaymentMethod.global.active.always_available)
              .includes(::PaymentCore::PaymentMethod.reference_classes.keys.map(&:to_sym))
            },
            available_payment_method: proc { |context: nil|
              payment_method_candidates.select do |pm|
                pm.available?(context: context, holder: self)
              end
            },
            api: ::PaymentCore.config.plugins_config.build(**{
              finder: proc { |holder_id|
                find(holder_id)
              },
              type: proc {
                      name.demodulize.underscore
                    }
            })
          }
        end

        module ClassMethods
          def payment_method_holder(**opts, &block)
            # unless ::ActiveRecord::Base.connection.table_exists?('payment_core_payment_methods')

            default_opts = ::PaymentCore::Models::Decorators::PaymentMethodHolder.default_options
            ::PaymentCore::Models::Decorators::PaymentMethodHolder.plugins_config.setup(self, 'payment_method_holder_config', opts, default_opts,
                                                      method_prefix: 'payment_method_holder', &block)

            include DepedencyHooks
            include Hooks
            extend Hooks::ClassMethods
            include RelationHooks
            extend RelationHooks::ClassMethods
            extend PaymentMethodCallbacks

            payment_method_holder_setup do
              define_payment_method_holder_payment_method_relations
              define_payment_method_holder_entry_relations
            end

            ::PaymentCore::Models::Decorators::PaymentMethodHolder << self

            define_inheritable_singleton_method(:payment_method_holder?) { true }

            include InstanceMethods
          end

          def payment_method_holder?
            false
          end

        end

        module DepedencyHooks
          extend ActiveSupport::Concern
          included do
            include ::Plugins.decorators.method_annotations
            include ::Plugins.decorators.inheritables
            include ::Plugins.decorators.hooks
          end
        end

        module Hooks
          module ClassMethods

            def inherited(subclass)
              super(subclass)
              after_class_defined(subclass) do
                ::PaymentCore::Models::Decorators::PaymentMethodHolder << subclass
              end
            end

            def payment_method_holder_setup &block
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

            def define_payment_method_holder_payment_method_relations
              ::PaymentCore::Models::Decorators::PaymentMethod::Object.registered_classes.each do |klass|
                define_payment_method_holder_payment_method_relation
              end
            end

            def define_payment_method_holder_payment_method_relation(klass = ::PaymentCore::PaymentMethod)
              assoc_name = klass.payment_method_relation_name_on_holder
              unless reflect_on_association(assoc_name)
                has_many assoc_name, class_name: klass.name, as: :holder
                klass.define_alternative_of_relation(self, relation: :holder)
              end
            end

            def define_payment_method_holder_entry_relations
              ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.each do |klass|
                define_payment_method_holder_entry_relation
              end
            end

            def define_payment_method_holder_entry_relation(klass= ::PaymentCore::Entry)
              assoc_name = klass.entry_relation_name_on_holder
              unless reflect_on_association(assoc_name)
                has_many assoc_name, through: ::PaymentCore::PaymentMethod.payment_method_relation_name_on_holder, source: ::PaymentCore::PaymentMethod.payment_method_relation_name_on_entry
              end
            end

          end
        end

        module PaymentMethodCallbacks
          extend ActiveSupport::Concern
          included do
            define_inheritable_singleton_method :payment_method_availability do |method_name, &block|
              annotate_method(method_name, payment_method_availability: true, &block)
            end
          end
        end

        module InstanceMethods
          def payment_method_candidates
            payment_method_holder_payment_method_candidates
          end

          def available_payment_methods(context: nil)
            payment_method_holder_available_payment_method(context: context)
          end

          def should_payment_method_be_available?(payment_method, context, *args)
            return true if self.class.methods_annotated_with(:payment_method_availability, true).empty?
            availabilities = self.class.methods_annotated_with(:payment_method_availability, true).select{|mname| self.class.method_annotated_with?(mname, :method_types, :all) }
            availabilities = availabilities.concat(self.class.methods_annotated_with(:payment_method_availability, true).select{|mname| self.class.method_annotated_with?(mname, :method_types, payment_method.method_type.to_sym) })
            availabilities.all? do |method_name|
              arguments = args.unshift(context)
              arguments = args.unshift(payment_method)
              avail = smart_send(method_name, arguments)
              avail.nil?? true : avail
            end

            # self.class.methods_annotated_with(:payment_method_availability, true).empty? ||
            #   self.class.methods_annotated_with(:payment_method_availability, true).all? do |method_name|
            #     avail = send(method_name, payment_method, context, *args)
            #     avail.nil?? true : avail
            #   end
          end

        end
      end
    end
  end
end
