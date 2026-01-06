module PaymentCore
  module Models
    module Decorators
      module Payable
        mattr_accessor :payable_classes
        @@payable_classes = Set.new

        def self.<<(klass)
          @@payable_classes << klass #unless @@payable_classes.include?(klass)
        end

        def self.included(base)
          base.define_method :payable? do
            false
          end
          base.extend ClassMethods
        end

        def self.default_options
          {
            # number: proc {
            #   "#{self.class.name.demodulize.underscore.capitalize}-#{id.to_s.rjust(6, '0')}"
            # },
            number: :id,
            description: nil,
            quantity: 1,
            total_item_amount: 0,
            total_amount: 0,
            paid_amount: proc {
              components = Array(payable_components).flatten
              payable_entries.with_entry_types("charge").succeeded.or(
                  ::PaymentCore::Entry.with_entry_types("charge").succeeded.where( payable: components, parent: payable_wrapper_entries.succeeded)
                )
                .sum(:amount)
            },
            unpaid_amount: proc {
              payable_total_amount - payable_paid_amount
            },
            currency: nil,
            status: proc {
              payable_state = 'unpaid'
              payable_state = 'paid' if payable_paid_amount >= payable_total_amount
              payable_state = 'partial' if payable_paid_amount > 0 && payable_paid_amount < payable_total_amount
              payable_state
            },
            components: proc {
              self
            },
            payment_method_item_amount: proc { |payment_method|
              payable_total_item_amount.to_d / payable_quantity
            },
            payment_method_total_amount: proc { |payment_method|
              payable_quantity * payable_payment_method_item_amount(payment_method)
            },
            to_payment_method_amount: proc {|payment_method, amount|
              payable_payment_method_total_amount(payment_method) * (amount.to_d / payable_total_amount)
            },
            from_payment_method_amount: proc { |payment_method, payment_method_amount|
              payable_total_amount * (payment_method_amount.to_d / payable_payment_method_total_amount(payment_method))
            },
            api: ::PaymentCore.config.plugins_config.build(**{
              finder: proc { |payable_id|
                find(payable_id)
              },
              finders: proc { |ids|
                        where(id: ids)
                      },
              type: proc {
                      name.demodulize.underscore
                    }
            })
          }
        end

        module ClassMethods
          def payable(**opts, &block)
            # return unless ::ActiveRecord::Base.connection.table_exists?('payment_core_entries')

            default_opts = ::PaymentCore::Models::Decorators::Payable.default_options
            ::PaymentCore.config.plugins_config.setup(self, 'payable_config', opts, default_opts,
                                                      method_prefix: 'payable', &block)
            unless reflect_on_association(:payable_entries)
              has_many :payable_entries, class_name: 'PaymentCore::Entry', as: :payable
              ::PaymentCore::Entry.descendants.each { |sub| define_payable_entry_subclass_relation(sub) }
              assoc_name = "payable_entry_payable_of_#{base_class.name.demodulize.underscore}"
              ::PaymentCore::Entry.define_alternative_polymorphic_parent_association assoc: :payable,
                                                                                     new_assoc: assoc_name, base_class: base_class
            end
            unless reflect_on_association(:payable_payment_intents)
              has_many :payable_payment_intents, class_name: 'PaymentCore::PaymentIntent', as: :payable
              ::PaymentCore::PaymentIntent.descendants.each do |sub|
                define_payable_payment_intent_subclass_relation(sub)
              end
              ::PaymentCore::PaymentIntent.define_alternative_polymorphic_parent_association assoc: :payable,
                                                                                             new_assoc: assoc_name, base_class: base_class
            end

            include ::Plugins.decorators.method_annotations
            include ::Plugins.decorators.inheritables

            define_inheritable_singleton_method :payment_method_availability do |method_name = nil, method_types: :all, &block|
              method_name ||= :"payment_method_availability_#{SecureRandom.hex(8)}"
              annotate_method(method_name, payment_method_availability: true, method_types: method_types, &block)
            end

            define_inheritable_singleton_method :payable_entries_callback do |*args, &block|
              opts = args.extract_options!
              callback_name = args[0]
              method_name = args[1]
              opts = { source: :payable, if: proc { payable.present? }, exclusive: false }.merge(opts)
              callback_for(::PaymentCore::Entry, callback_name, method_name, opts, &block)
              ::PaymentCore::Entry.descendants.each do |subclass|
                callback_for(subclass, callback_name, method_name, opts, &block)
              end
            end

            include InstanceMethods
            include InheritableHook
            ::PaymentCore::Models::Decorators::Payable << self
          end

          def define_payable_entry_subclass_relation(sub)
            unless reflect_on_association("payable_#{sub.entry_type}_entries".to_sym)
              has_many "payable_#{sub.entry_type}_entries".to_sym, class_name: sub.name, as: :payable
            end
          end

          def define_payable_payment_intent_subclass_relation(sub)
            unless reflect_on_association("payable_#{sub.intent_name}_payment_intents".to_sym)
              has_many "payable_#{sub.intent_name}_payment_intents".to_sym, class_name: sub.name, as: :payable
            end
          end
        end

        module InheritableHook
          extend ActiveSupport::Concern

          included do
            class << self
              def inherited(subclass)
                super(subclass)
                ::PaymentCore::Models::Decorators::Payable << subclass
              end
            end
          end
        end

        module InstanceMethods
          def payable?
            true
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
          end
        end
      end
    end
  end
end
