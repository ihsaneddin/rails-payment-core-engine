module PaymentCore
  module PaymentMethods
    class PaymentPackage < PaymentCore::PaymentMethod

      self.method_type= 'payment_package'

      class Metadata < ::PaymentCore::Attributes::PaymentMethods::Metadata
        attribute :number, :string
        attribute :balance, :decimal, precision: 8, scale: 2, default: 0
        attribute :account_id, :string
        attribute :currency, :string
      end

      custom_attributes_definition :metadata, Metadata, accessor: true, prefix: ''
      uses_reference(required: true, use_reference: true, use_reference_attributes: true)
      expirable(required: false)
      refundable

      reference_payment_method :active do
        active
      end

      reference_payment_method :number do
        nil
      end

      reference_payment_method :account_id do
        nil
      end

      reference_payment_method :balance do
        0
      end

      reference_payment_method :currency do
        currency
      end

      reference_payment_method :convert_to_amount do |_payable, *_args|
        0
      end

      reference_payment_method :package do
        reference.currency.reference
      end

      entry_callback :validate, if: proc { payable.present? } do |entry|
        entry.errors.add(:balance, 'Insufficient balance') if entry.charge? && (entry.payment_method_amount > balance) && entry.state_will_be_succeeded?
      end

      entry_callback :validate do |entry|
        entry.errors.add(:invalid, :currency) unless entry.currency != currency
      end

      entry_callback :after_save do |entry|
        if entry.charge? && entry.after_state_succeeded?
          Ewallet::Entry.payment(
            source_account_id: account_id,
            amount: entry.payment_method_amount,
            reference: entry,
            currency: currency,
            description: entry.description
          )
        end
      end

      entry_callback :after_save, if: proc { refund? } do |entry|
        if entry.refund? && entry.after_state_succeeded? && (ewallet_payment_entry = Ewallet::Entries::Payment.where(reference: entry.payable).first) && (entry.payment_method_amount == ewallet_payment_entry.source.amount)
          Ewallet::Entry.refund(
            refund_entry: ewallet_payment_entry,
            target_account_id: account_id,
            amount: entry.payment_method_amount,
            reference: entry,
            description: entry.description
          )
        end
      end

      def amount_available_for(payable, remaining_method_amount: nil)
        [super(payable, remaining_method_amount: remaining_method_amount), balance].compact.min
      end
    end
  end
end
