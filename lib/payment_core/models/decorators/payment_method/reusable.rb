module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module Reusable

          # module Metadata
          #   extend ActiveSupport::Concerns
          #   included do
          #     self.protected_attributes = self.protected_attributes + [:usage_reset_at, :current_usage]

          #     attribute :max_usage_limit, :integer, default: nil
          #     attribute :max_usage_limit_per_period, :integer, default: nil
          #     attribute :usage_period_type, :string, default: nil
          #     attribute :current_usage, :integer, default: 0
          #     attribute :usage_reset_at, :datetime, default: nil

          #     validates :reusable_period_type, inclusion: { in: %w[day week month year], allow_blank: true }
          #   end

          # end

          def self.included(base)
            invalid_class?(base)

            base.extend ClassMethods
          end

          # def self.default_options
          #   {
          #     max_uses: nil,
          #     max_uses_per_period: nil,
          #     max_uses_period: nil,
          #     usage_scope: proc { |entry|
          #       ['charge', 'withdraw', 'transfer'].include?(entry.class.entry_type) && entry.succeeded?
          #     },
          #   }
          # end

          module ClassMethods
            def reuseable(**opts, &block)
              # default_opts = ::PaymentCore::Models::Decorators::PaymentMethod.reusable.default_options
              # ::Plugins::Models::Concerns::Config.setup(self, 'expirable_config', opts, default_opts, &block)

              # metadata_class = attribute_types[:metadata]
              # metadata_class.include(::PaymentCore::Models::Decorators::PaymentMethod::Reusable::Metadata)
              # custom_attributes_definition :metadata, metadata_class, accessor: true

              # define_inheritable_singleton_method(:expirable?) { true }
            end
          end

          module InstanceMethods
            def should_payment_method_be_available?(context, *_args)
              super(context, *args)
            end
          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object

        end
      end
    end
  end
end
