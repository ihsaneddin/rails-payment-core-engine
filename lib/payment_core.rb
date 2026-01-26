require "payment_core/version"
require "payment_core/engine"
require 'alba'
require 'plugins'
require 'grape'
require 'grape-entity'
require 'state_machines-activerecord'

module PaymentCore

  autoload :Configuration, "payment_core/configuration"
  autoload :Controllers, "payment_core/controllers"
  autoload :Models, "payment_core/models"
  autoload :Services, "payment_core/services"
  autoload :Processors, "payment_core/processors"
  autoload :Gateways, "payment_core/gateways"
  autoload :Grape, "payment_core/grape"
  autoload :Errors, "payment_core/errors"
  autoload :Decorators, 'payment_core/decorators'
  autoload :AttributeTypes, "payment_core/attribute_types"

  mattr_accessor :configuration
  @@configuration = Configuration

  def self.config
    @@configuration
  end

  def self.setup &block
    config.setup &block
  end

  def self.decorators
    Decorators
  end

end

require "payment_core/railtie"
