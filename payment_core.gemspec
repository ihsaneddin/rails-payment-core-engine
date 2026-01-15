require_relative "lib/payment_core/version"

Gem::Specification.new do |spec|
  spec.name        = "payment_core"
  spec.version     = PaymentCore::VERSION
  spec.authors     = ["VirtualSpirit"]
  spec.email       = ["admin@virtualspirit.ai"]
  spec.homepage    = "https://virtualspace.ai"
  spec.summary     = "Payment module"
  spec.description = "Payment module"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  #spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/virtualspirit/event_backend"
  spec.metadata["changelog_uri"] = "https://github.com/virtualspirit/event_backend"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", '~> 7.0.2', '>= 7.0.2.2'
  spec.add_dependency "plugins"
  spec.add_dependency "aasm"
  spec.add_dependency "paranoia"
  spec.add_dependency 'ransack', '>= 3.1.0'
  spec.add_dependency 'grape'
  spec.add_dependency 'grape-entity'
  spec.add_dependency 'grape-kaminari'
  spec.add_dependency 'alba'
  spec.add_dependency "sidekiq"
  spec.add_dependency 'sidekiq-scheduler'
  spec.add_dependency 'hashdiff'
  spec.add_dependency 'validates_timeliness'
  spec.add_dependency 'state_machines-activerecord'
end
