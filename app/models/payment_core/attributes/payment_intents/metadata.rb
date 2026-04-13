module PaymentCore
  class Attributes::PaymentIntents::Metadata < ::PaymentCore::Attributes::Base

    self.protected_attributes = [:allowed_entry_classes, :primary_entry_class]

    attribute :allowed_entry_classes, type: :string, array: true, default: []
    attribute :primary_entry_class, :string, default: ""
    attribute :strict_entry_class, :boolean, default: false
    attribute :processor_action, :string, default: "charge"

  end
end