module PaymentCore
  module Models
    module Decorators
      module Payable

        extend ::Plugins::Decorators::ConfigBuilder
        include ::Plugins.decorators.registered

        def self.payable_classes
          self.registered_classes
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
            payer: nil,
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
            }),
            entry_requirements: ::PaymentCore::Models::Decorators::Payable.plugins_collection_config.build(**{ rules: {} }),
            events: plugins_config.build(**{
              entry: plugins_config.build(**{
                created: nil,
                updated: nil,
                saved: nil,
                destroyed: nil
              })
            })
          }
        end

        def self.included(base)
          base.extend ClassMethods
          base.define_method :payable? do
            self.class.payable?
          end
        end

        module ClassMethods
          def payable(**opts, &block)
            #return unless ActiveRecord::Base.connection.table_exists?('payment_core_entries')
            default_opts = ::PaymentCore::Models::Decorators::Payable.default_options
            ::PaymentCore::Models::Decorators::Payable.plugins_config.setup(self, 'payable_config', opts, default_opts,
                                                      method_prefix: 'payable', &block)

            include DepedencyHooks
            include Hooks
            extend Hooks::ClassMethods
            include RelationHooks
            extend RelationHooks::ClassMethods
            include PaymentMethodCallbacks
            include PaymentIntentCallbacks
            include EntryCallbacks

            payable_setup do
              define_payable_entry_relations
              define_payable_payment_intent_relations
            end

            ::PaymentCore::Models::Decorators::Payable << self

            define_inheritable_singleton_method(:payable?) { true }

            include InstanceMethods
          end

          def payable?
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
                ::PaymentCore::Models::Decorators::Payable << subclass
              end
            end

            def payable_setup &block
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

            def define_payable_entry_relations
              ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.each do |klass|
                define_payable_entry_relation(klass)
              end
            end

            def define_payable_entry_relation(klass = ::PaymentCore::Entry)
              assoc_name = klass.entry_relation_name_on_payable
              unless reflect_on_association(assoc_name)
                has_many assoc_name, class_name: klass.name, as: :payable
                klass.define_alternative_of_relation(self, relation: :payable)
              end
            end

            def define_payable_payment_intent_relations
              ::PaymentCore::Models::Decorators::PaymentIntent::Object.registered_classes.each do |klass|
                define_payable_payment_intent_relation(klass)
              end
            end

            def define_payable_payment_intent_relation(klass= ::PaymentCore::PaymentIntent)
              assoc_name = klass.payment_intent_relation_name_on_payable
              unless reflect_on_association(assoc_name)
                has_many assoc_name, class_name: klass.name, as: :payable
                has_one "active_#{assoc_name.to_s.singularize}".to_sym, -> { order(created_at: :desc) }, class_name: klass.name, as: :payable
                klass.define_alternative_of_relation(self, relation: :payable)
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
          end
        end

        module EntryCallbacks
          extend ActiveSupport::Concern
          included do
            define_inheritable_singleton_method :payable_entries_callback do |*args, &block|
              opts = args.extract_options!
              callback_name = args[0]
              method_name = args[1]
              opts = { source: :payable, if: proc { payable.present? }, exclusive: false }.merge(opts)
              ::PaymentCore::Models::Decorators::Entry::Object.registered_classes.each do |klass|
                callback_for(klass, callback_name, method_name, opts, &block)
              end
              # callback_for(::PaymentCore::Entry, callback_name, method_name, opts, &block)
              # ::PaymentCore::Entry.descendants.each do |subclass|
              #   callback_for(subclass, callback_name, method_name, opts, &block)
              # end
            end
          end
        end

        module PaymentIntentCallbacks
          extend ActiveSupport::Concern
          included do
            define_inheritable_singleton_method :payable_payment_intent_callback do |*args, &block|
              opts = args.extract_options!
              callback_name = args[0]
              method_name = args[1]
              opts = { source: :payable, if: proc { payable.present? }, exclusive: false }.merge(opts)
              ::PaymentCore::Models::Decorators::PaymentIntent::Object.registered_classes.each do |klass|
                callback_for(klass, callback_name, method_name, opts, &block)
              end
              # callback_for(::PaymentCore::PaymentIntent, callback_name, method_name, opts, &block)
              # ::PaymentCore::PaymentIntent.descendants.each do |subclass|
              #   callback_for(subclass, callback_name, method_name, opts, &block)
              # end
            end
          end
        end

        module InstanceMethods

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

          def payable_paid?
            payable_status == "paid"
          end

        end
      end
    end
  end
end
