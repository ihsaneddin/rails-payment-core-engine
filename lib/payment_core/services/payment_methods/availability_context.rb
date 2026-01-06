module PaymentCore
  module Services
    module PaymentMethods
      class AvailabilityContext

        attr_accessor :regions, :currencies, :use_cases, :time, :data, :payables, :user

        def initialize **opts
          opts.deep_symbolize_keys!
          self.regions = Array(opts[:regions]).compact
          self.currencies = Array(opts[:currencies]).compact
          self.use_cases = Array(opts[:use_cases]).compact
          self.time = time || DateTime.now
          self.payables = Array(opts[:payables]).compact
          self.user = opts[:user]
          self.data = opts[:data] || {}
        end

      end
    end
  end
end