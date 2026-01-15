module PaymentCore
  module Processors
    class PaymentPackage < ::PaymentCore::Processors::Base

      self.method_type = "payment_package"

      params :charge_params do
        [:amount, :currency, :payable_id, :payable_type, :payable, :partial, :description]
      end

      action :charge do |params, *args|
        payable = params[:payable] ||
        if payable.nil? && params[:payable_type].present? && params[:payable_id].present?
          payable_class(params[:payable_type]).payable_api.finder(params[:payable_id])
        end

        entries = []

        if payable
          params[:amount] = payable.payable_unpaid_amount
        end

        allocator = PaymentCore::Services::PaymentMethods::ChargeAllocator.new(
          payable: payable,
          payment_methods: payment_method,
          context: context,
          payer: payer,
          allow_split: true,
        )

        allocations = allocator.allocate!

        allocations.each do |allocator|
          entry = PaymentCore::Entries::Charge.new(
            payment_method: allocator.payment_method,
            payer: payer,
            payable:allocator.payable,
            amount: allocator.amount,
            payment_method_amount: allocator.payment_method_amount,
            currency: params[:currency] || payable.payable_currency,
            description: params[:description],
            context: context,
            metadata: params[:metadata] || {}
          )
          entries << entry
        end

        PaymentCore::Entry.wrap( entries, { amount: params[:amount], partial: params[:partial], payer: payer, payable: payable, metadata: params[:metadata] }) do |entry|
          entry.success
        end

      end

      action_access :charge, :public

      params :charge_params, type: :collective do
        [:amount, :currency, :payable_id, :payable_type, :payable, :partial, :description]
      end

      collective_action :charge do |params, *args|
        payable = params[:payable] ||
        if payable.nil? && params[:payable_type].present? && params[:payable_id].present?
          payable_class(params[:payable_type]).payable_api.finder(params[:payable_id])
        end

        entries = []

        if payable
          params[:amount] = payable.payable_unpaid_amount
        end

        allocator = PaymentCore::Services::PaymentMethods::ChargeAllocator.new(
          payable: payable,
          payment_methods: payment_method,
          context: context,
          payer: payer,
          allow_split: true,
          split_method: :greedy_split
        )

        allocations = allocator.allocate!

        allocations.each do |allocator|
          entry = PaymentCore::Entries::Charge.new(
            payment_method: allocator.payment_method,
            payer: payer,
            payable:allocator.payable,
            amount: allocator.amount,
            payment_method_amount: allocator.payment_method_amount,
            currency: params[:currency] || payable.payable_currency,
            description: params[:description],
            context: context,
            metadata: params[:metadata] || {},
            partial: true,
          )
          entries << entry
        end

        PaymentCore::Entry.wrap( entries, { amount: params[:amount], partial: params[:partial], payer: payer, payable: payable, metadata: params[:metadata] }) do |entry|
          entry.success
        end

      end


      params :refund_params do
        [:payable_id, :payable_type, :payable, :description]
      end

      action :refund do |params, *args|
        payable = params[:payable] ||
        if payable.nil? && params[:payable_type].present? && params[:payable_id].present?
          payable_class(params[:payable_type]).payable_api.finder(params[:payable_id])
        end

        refund = PaymentCore::Entries::Refund.new(use_payable_data: true, payable: payable, description: params[:description])
        refund.success
        refund
      end



      def payable_class payable_type
        payable_type.safe_constantize ||
        ::PaymentCore::Models::Decorators::Payable.registered_classes.find{|klass| klass.payable_api.type == payable_type } ||
        raise { ::ActiveRecord::RecordNotFound }
      end

    end
  end
end
