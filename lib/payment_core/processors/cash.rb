module PaymentCore
  module Processors
    class Cash < Base

      self.method_type= "cash"

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

      params :charge_params do
        [:amount, :currency, :payable_id, :payable_type, :payable, :partial, metadata: {}]
      end

      def payable_class payable_type
        payable_type.safe_constantize ||
        ::PaymentCore::Models::Decorators::Payable.registered_classes.find{|klass| klass.payable_config.tipe == payable_type } ||
        raise { ::ActiveRecord::RecordNotFound }
      end

    end
  end
end
