$LOAD_PATH.unshift(File.expand_path(__dir__)) unless $LOAD_PATH.include?(File.expand_path(__dir__))

RSpec.configure do |config|
  # Make spec discovery work even when running from subdirectories (e.g., ./spec)
  config.default_path = File.expand_path(__dir__)
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
