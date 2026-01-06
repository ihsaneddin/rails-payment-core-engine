module PaymentCore
  class PaymentIntent < ::PaymentCore.config.application_record_base_constant

    self.table_name = "payment_core_payment_intents"

    acts_as_paranoid if ::PaymentCore.config.soft_delete_enabled

    include ::Plugins::Models::Concerns::PolymorphicAlternative
    class_attribute :intent_name

    def self.inherited(subclass)
      super(subclass)
      subclass.set_intent_name
      @intent_names ||= Set.new
      if @intent_names.include?(subclass.intent_name)
        raise ArgumentError, "Duplicate intent_name '#{name}' detected for #{subclass}"
      end
      ::PaymentCore::Models::Decorators::PaymentCore.payable_classes.each do |payable_class|
        payable_class.define_payable_payment_intent_subclass_relation(subclass)
      end
    end
    def self.set_intent_name(ename = nil)
      self.intent_name = ename || name.demodulize.underscore
    end

  end
end
