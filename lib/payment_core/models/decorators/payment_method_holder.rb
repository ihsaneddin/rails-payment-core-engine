module PaymentCore
  module Models
    module Decorators
      module PaymentMethodHolder
        mattr_accessor :holder_classes
        @@holder_classes = Set.new

        def self.<<(klass)
          @@holder_classes << klass #unless @@holder_classes.include?(klass)
        end

        def self.included(base)
          base.define_method :payment_method_holder? do
            false
          end
          base.include ::Plugins.decorators.inheritables
          base.extend ClassMethods
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

            default_opts = ::PaymentCore.decorators.payment_method_holder.default_options
            ::Plugins::Models::Concerns::Config.setup(self, 'payment_method_holder_config', opts, default_opts,
                                                      method_prefix: 'payment_method_holder', &block)

            unless reflect_on_association(:payment_methods)
              has_many :payment_methods, class_name: 'PaymentCore::PaymentMethod', as: :holder
              ::PaymentCore::PaymentMethod.descendants.each { |sub| define_payment_method_subclass_relation(sub) }
              assoc_name = "payment_method_holder_of_#{base_class.name.demodulize.underscore}"
              ::PaymentCore::PaymentMethod.define_alternative_polymorphic_parent_association assoc: :holder,
                                                                                             new_assoc: assoc_name, base_class: base_class
            end

            unless reflect_on_association(:payment_entries)
              has_many :payment_entries, class_name: 'PaymentCore::Entry', as: :payer
            end

            include ::Plugins.decorators.method_annotations
            define_inheritable_singleton_method :payment_method_availability do |method_name, &block|
              annotate_method(method_name, payment_method_availability: true, &block)
            end

            include InstanceMethods
            include InheritableHook
            ::PaymentCore.decorators.payment_method_holder << self
          end

          def define_payment_method_subclass_relation(sub)
            unless reflect_on_association("payment_method_#{sub.method_type.pluralize}".to_sym)
              has_many "payment_method_#{sub.method_type.pluralize}".to_sym, class_name: sub.name, as: :holder
            end
          end
        end

        module InheritableHook
          extend ActiveSupport::Concern

          included do
            class << self
              def inherited(subclass)
                super(subclass)
                ::PaymentCore.decorators.payment_method_holder << subclass
              end
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

          def payment_method_holder?
            true
          end
        end
      end
    end
  end
end
