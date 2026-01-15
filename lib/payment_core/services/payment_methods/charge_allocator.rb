module PaymentCore
  module Services
    module PaymentMethods
      class ChargeAllocator

        class Allocation

          attr_accessor :payable, :payment_method, :amount, :payment_method_amount, :source, :payable_component_ids

          def initialize payable:, payment_method: ,amount: , payment_method_amount:, source: "split", payable_component_ids:
            self.payable = payable
            self.payment_method = payment_method
            self.amount = amount
            self.payment_method_amount = payment_method_amount
            self.source = source
            self.payable_component_ids = payable_component_ids
          end

        end

        module Object

          mattr_accessor :registry
          @@registry = Set.new

          def self.<< klass
            @@registry <<  klass
          end

          def self.default_config
            {
              sort: :sort,
              availability: :payment_method_availability,
              split: :split
            }
          end


          def self.included base
            base.include ::Plugins.decorators.inheritables
            base.include ::Plugins.decorators.method_annotations
            base.include ::Plugins.decorators.method_decorators
            base.extend ClassMethods
            base.include InstanceMethods
            base.inheritable_class_attribute :allocator_type
            base.allocator_type= base.name.demodulize.underscore
            base.attr_accessor :payable, :total_amount, :payment_methods, :context, :payer, :allow_split, :split_method, :payable_component_ids

            base.define_inheritable_singleton_method :sort do |method_name = nil, direction: :asc,  priority: 1, &block|
              method_name ||= :"sort_#{SecureRandom.hex(8)}"
              unless block.arity != 2
                raise ArgumentError, "The method should accept two argument"
              end
              annotate_method(method_name, sort: true, sort_direction: direction, sort_priority: priority &block)
            end

            base.define_inheritable_singleton_method :eligibility do |method_name = nil, priority= 100, &block|
              method_name ||= :"eligibility_#{SecureRandom.hex(8)}"
              annotate_method(method_name, eligibility: true, eligibility_priority: priority &block)
            end

            base.define_inheritable_singleton_method :split_method do |method_name = nil, default: false, &block|
              method_name ||= :"split_method_#{SecureRandom.hex(8)}"
              annotate_method(method_name, split_method: true, &block)
              if default
                annotate_method!(method_name, default_split_method: true)
              end
            end

            ::Plugins::Models::Concerns::Config.setup(base, "config", {}, default_config, method_prefix: "config")

            base.split_method(:greedy_split, default: true)
            base.split_method(:even_split)

            ::PaymentCore::Services::PaymentMethods::ChargeAllocator::Object << base

          end

          module ClassMethods
            def inherited subclass
              super(subclass) if defined? super
              subclass.allocator_type = self.name.demodulize.underscore
              ::PaymentCore::Services::PaymentMethods::ChargeAllocator::Object << subclass
            end
          end

          module InstanceMethods

            def initialize( payable:, total_amount: 0, payment_methods: [], context:, payer: nil, allow_split: false, split_method: nil, payable_component_ids: nil, &block)
              self.payable = payable
              self.total_amount = total_amount.to_d
              if payable
                self.total_amount = self.payable.payable_unpaid_amount
              end
              self.payment_methods = Array(payment_methods).flatten.compact
              self.context = context
              self.payer = payer
              self.allow_split = allow_split
              self.split_method = split_method
              if block_given?
                self.config.setup(&block)
              end
              self.payable_component_ids = payable_component_ids
            end

            def allocate!()
              components = []
              if payable
                components = Array(self.payable.payable_components).flatten.select{|component| component.payable_status != "paid" }
                if payable_component_ids.is_a?(Array)
                  components = components.select{|c| payable_component_ids.include?(c.id) }
                end
              end
              sorted_payment_methods = config.sort(payment_methods)
              allocations = []

              if components.empty?
                available_payment_methods = sorted_payment_methods.select{|pm| !pm.requires_payable? }
                return allocations if available_payment_methods.empty?
                if allow_split
                  allocations.concat(split(payable, available_payment_methods))
                else
                  allocation = allocate_without_split(payable, available_payment_methods)
                  allocations << allocation if allocation
                end
              else
                components.each do |component|
                  available_payment_methods = sorted_payment_methods.select do |pm|
                    config.availability(pm, component)
                  end

                  next if available_payment_methods.empty?

                  component_allocations = []

                  if allow_split
                    component_allocations = split(component, available_payment_methods)
                  else
                    allocation = allocate_without_split(component, available_payment_methods)
                    component_allocations << allocation if allocation
                  end
                  allocations.concat(component_allocations)
                end
              end


              allocations
            end

            def allocate_without_split(payable, payment_methods)
              payment_methods.each do |pm|
                #next unless config.availability(pm, payable)
                if payable
                  method_amount_needed = payable.payable_to_payment_method_amount(pm, payable.payable_unpaid_amount)
                else
                  method_amount_needed = self.total_amount
                end

                available_amount = pm.amount_available_for(payable, remaining_method_amount: method_amount_needed)

                next if available_amount < method_amount_needed

                return Allocation.new(
                  payable: payable,
                  payment_method: pm,
                  amount: payable ? payable.payable_unpaid_amount : self.total_amount,
                  payment_method_amount: method_amount_needed,
                  source: "full",
                  payable_component_ids: self.payable_component_ids
                )
              end

              nil
            end

            def sort(payment_methods = [])
              sorters = self.class.methods_annotated_with(:sort, true).inject([]) { |arr, sorter|
                annotations = self.class.annotations_for(sorter)
                arr = { sorter: sorter, priority: annotations[:sort_priority], direction: annotations[:sort_direction] }
                arr
              }.sort_by{ |s| s[:priority] || 0 }

              payment_methods.sort do |a, b|
                sorters.lazy.map { |s|
                  result = smart_send(s[:sorter], [a, b])
                  result && s[:direction] == :desc ? -result : result
                }.find { |r| r != 0 } || 0
              end
            end

            def payment_method_availability(pm, payable)
              ctx = if context
                ctx = context.dup
              end
              pm.available?(context: ctx, payables: Array(payable).compact )
            end

            def split component, available_payment_methods
              split_method = self.split_method || self.class.methods_annotated_with(:default_split_method, true)[0] || :greedy_split
              smart_send(split_method.to_sym, [component, available_payment_methods])
            end

            def greedy_split(payable, available_payment_methods: [])
              remaining_base_amount = payable ? payable.payable_unpaid_amount : self.total_amount#payable.payable_total_amount
              allocations = []
              available_payment_methods.each do |payment_method|
                break if remaining_base_amount.zero?
                if payable
                  remaining_method_amount = payable.payable_to_payment_method_amount(payment_method, remaining_base_amount)
                  available_method_amount = payment_method.amount_available_for(
                    payable,
                    remaining_method_amount: remaining_method_amount
                  )
                else
                  remaining_method_amount = remaining_base_amount
                  available_method_amount = payment_method.amount_available_for(
                    payable,
                    remaining_method_amount: remaining_method_amount
                  )
                end
                next if available_method_amount.zero?
                if payable
                  allocated_base_amount = payable.payable_from_payment_method_amount(
                    payment_method,
                    available_method_amount
                  )
                else
                  allocated_base_amount = available_method_amount
                end
                next if allocated_base_amount.zero? #|| allocated_base_amount > available_method_amount

                allocations << Allocation.new(
                  payable: payable,
                  payment_method: payment_method,
                  amount: allocated_base_amount,
                  payment_method_amount: available_method_amount,
                  source: "greedy_split",
                  payable_component_ids: self.payable_component_ids
                )
                remaining_base_amount -= allocated_base_amount
                break if remaining_base_amount <= 0
              end
              allocations
            end

            def even_split(payable, available_payment_methods: [])
              remaining_base_amount = payable ? payable.payable_unpaid_amount : self.total_amount#payable.payable_total_amount
              method_count = available_payment_methods.size
              return [] if method_count.zero?

              # Calculate equal target base amount for each method
              base_split_amount = (remaining_base_amount.to_d / method_count).floor(2)

              allocations = []

              available_payment_methods.each_with_index do |payment_method, index|
                break if remaining_base_amount.zero?

                # For last payment method, give it whatever remains to avoid rounding errors
                target_base_amount = if index == method_count - 1
                                      remaining_base_amount
                                    else
                                      base_split_amount
                                    end

                # Convert target base amount into payment method amount
                if payable
                  target_method_amount = payable.payable_to_payment_method_amount(payment_method, target_base_amount)
                  # Fetch available method amount
                  available_method_amount = payment_method.amount_available_for(
                    payable,
                    remaining_method_amount: target_method_amount
                  )
                else
                  target_method_amount = target_base_amount
                  # Fetch available method amount
                  available_method_amount = payment_method.amount_available_for(
                    payable,
                    remaining_method_amount: target_method_amount
                  )
                end

                next if available_method_amount.zero?

                # Convert back to base to see how much we can actually allocate
                if payable
                  allocated_base_amount = payable.payable_from_payment_method_amount(
                    payment_method,
                    available_method_amount
                  )
                else
                  allocated_base_amount= available_method_amount
                end

                next if allocated_base_amount.zero?

                allocations << Allocation.new(
                  payable: payable,
                  payment_method: payment_method,
                  amount: available_method_amount,
                  payment_method_amount: allocated_base_amount,
                  source: "even_split",
                  payable_component_ids: self.payable_component_ids
                )

                remaining_base_amount -= allocated_base_amount
              end

              allocations
            end


          end

        end

        include Object

      end
    end
  end
end