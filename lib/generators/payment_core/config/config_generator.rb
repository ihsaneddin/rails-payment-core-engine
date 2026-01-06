module PaymentCore
  module Generators
    class ConfigGenerator < Rails::Generators::Base
      source_root File.join(__dir__, "templates")

      def generate_config
        copy_file "payment_core.rb", "config/initializers/payment_core.rb"
      end
    end
  end
end