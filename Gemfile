source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in payment_core.gemspec.
gemspec

gem "puma"

group :development, :test do
  gem 'pg'
  gem 'byebug'
  gem 'rspec-rails'
end

gem "sprockets-rails"
gem 'ransack', '~> 3.1.0'

gem 'pagy', '~> 6.5.0'

gem 'plugins', path: "../plugins"
gem 'ewallet', path: "../rails-ewallet-engine"
gem 'order_core', path: "../order_core"

gem "state_machines-activerecord", git: "https://github.com/ihsaneddin/state_machines-activerecord.git", branch: "rails-7-0-fiber-fix"

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
