ENV["RAILS_ENV"] ||= "test"

require_relative "spec_helper"

unless defined?(Rails) && Rails.application&.initialized?
  require File.expand_path("dummy/config/environment", __dir__)
end
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

Dir[PaymentCore::Engine.root.join("spec/support/**/*.rb")].sort.each { |f| require f }
Dir[PaymentCore::Engine.root.join("spec/dummy/lib/**/*.rb")].sort.each { |f| require f }
Dir[PaymentCore::Engine.root.join("spec/dummy/app/subscribers/**/*.rb")].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::NoDatabaseError => e
  warn "Database not available: #{e.message}"
end

RSpec.configure do |config|
  config.fixture_path = File.expand_path("fixtures", __dir__)

  config.use_transactional_fixtures = false
  if defined?(DatabaseCleaner)
    config.before(:suite) do
      DatabaseCleaner.strategy = :truncation
      DatabaseCleaner.clean_with(:truncation)
    end

    config.around(:each) do |example|
      DatabaseCleaner.cleaning do
        example.run
      end
    end
  else
    config.before(:each) do
      begin
        connection = ActiveRecord::Base.connection
        tables = %w[
          users
          products
          payment_package_product_values
          order_core_orders
          order_core_line_items
          payment_core_payment_methods
          payment_core_entries
          payment_core_payment_intents
          ewallet_wallets
          ewallet_accounts
          ewallet_entries
          ewallet_amounts
          ewallet_issuers
          ewallet_currencies
        ]
        tables.each do |table|
          next unless connection.table_exists?(table)

          connection.execute("TRUNCATE TABLE #{table} RESTART IDENTITY CASCADE")
        end
      rescue ActiveRecord::NoDatabaseError => e
        warn "Database not available: #{e.message}"
      end
    end
  end

  config.before(:suite) do
    PaymentCore
  end

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end

