module PaymentCore
  module Models
    module Decorators
      module PaymentMethod
        module Expirable
          def self.included base
            invalid_class?(base)
            base.extend ClassMethods
          end

          def self.default_options
            {
              required: true
            }
          end

          module ClassMethods

            def expirable(**opts, &block)
              default_opts = ::PaymentCore::Models::Decorators::PaymentMethod::Expirable.default_options
              ::Plugins::Models::Concerns::Config.setup(self, 'expirable_config', opts, default_opts, &block)

              validates :expires_at, timeliness: { type: :datetime, after: :now, allow_blank: true }

              with_options if: proc { |record| record.expirable_config.required } do
                validates :expires_at, presence: true
              end

              define_inheritable_singleton_method(:expirable?) { true }

              include InstanceMethods
              reference_payment_method :expired?

            end

            def expirable?
              false
            end

          end

          module InstanceMethods

            def expired?
              expires_at.present? && expires_at >= DateTime.now
            end

            def active
              expired? && super
            end

          end

          extend ::PaymentCore::Models::Decorators::PaymentMethod::Object

        end
      end
    end
  end
end
