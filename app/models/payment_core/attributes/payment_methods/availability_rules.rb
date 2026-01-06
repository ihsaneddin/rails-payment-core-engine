module PaymentCore
  class Attributes::PaymentMethods::AvailabilityRules < ::PaymentCore::Attributes::Base
    include StoreModel::Model
    include ::Plugins.decorators.method_annotations

    def self.matcher method_name, context_key, &block
      annotate_method(method_name, matcher: true, context_key: context_key, &block)
    end

    attribute :regions, array: true, default: []
    attribute :currencies, array: true, default: []
    attribute :disallowed_use_cases, array: true, default: []

    matcher(:match_region?, :regions) do |region|
      regions.blank? || regions.any?{|reg| Array(region).compact.include?(reg)}
    end

    matcher(:match_currency?, :currencies) do |currency|
      currencies.blank? || currencies.any?{|curr| Array(currency).compact.include?(curr)}
    end

    matcher(:allowed_use_case?, :use_cases) do |use_case|
      return true if disallowed_use_cases.blank?
      !disallowed_use_cases.any?{|uc| Array(use_case).compact.include?(use_case) }
    end

    def should_payment_method_be_available?(context = nil)
      return true if context.nil?
      self.class.methods_annotated_with(:matcher, true).all? do |method|
        annotation = self.class.annotations_for(method)
        ctx_key = annotation[:context_key]

        next true if ctx_key.blank?
        next true unless context.respond_to?(ctx_key)

        value = context.public_send(ctx_key)
        send(method, value) rescue false
      end
    end

  end
end