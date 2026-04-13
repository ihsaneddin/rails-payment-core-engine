module PaymentCore
  module Processors
    class BankTransfer < Base

      self.method_type = "bank_transfer"

      params :charge_params do
        [:payable_id, :payable_type, :payable, metadata: {}]
      end

      action :charge do |params, *args|
        payable = params[:payable] ||
        if !payable.class.try(:payable?) && params[:payable_type].present? && params[:payable_id].present?
          payable_class(params[:payable_type]).payable_api.finder(params[:payable_id])
        end
        if payment_method.require_intent? && payable.active_payable_payment_intent.blank?
          entry = PaymentCore::Entries::Charges::BankTransfer.new
          entry.errors.add(:payment_intent_id, :required)
          next entry
        end

        amount = payable&.payable_unpaid_amount
        payment_method_amount = payable&.payable_to_payment_method_amount(payment_method, amount) if amount

        entry = PaymentCore::Entries::Charges::BankTransfer.create(
          payment_intent: payable.active_payable_payment_intent,
          payment_method: payment_method,
          payer: payer,
          payable: payable,
          amount: amount,
          payment_method_amount: payment_method_amount,
          currency: payable&.payable_currency,
          description: params[:description],
          context: context,
          metadata: params[:metadata] || {}
        )

        next entry
      end

      action_access :charge, :public

      params :request_verification_params do
        [:payable_id, :payable_type, :requested_by, :requested_at, proof: [:file_url, :note]]
      end

      action :request_verification do |params, *args|
        payable = params[:payable] ||
        if !payable.class.try(:payable?) && params[:payable_type].present? && params[:payable_id].present?
          payable_class(params[:payable_type]).payable_api.finder(params[:payable_id])
        end

        entry_id = params[:entry_id]

        entry = if payable
          scope = payable.payable_entries
            .with_entry_types(PaymentCore::Entries::Charges::BankTransfer.entry_type)
            .where(payment_method: payment_method)
            .order(created_at: :desc)
          if entry_id
            scope.find(entry_id)
          else
            scope.first
          end
        end

        unless entry
          entry = PaymentCore::Entries::Charges::BankTransfer.new
          entry.errors.add(:base, :not_found)
          next entry
        end

        if params[:proof].present?
          proof_params = params[:proof].to_h.deep_symbolize_keys.slice(:file_url, :note)
          entry.metadata.add_proof(proof_params)
        end

        request_params = params.slice(:requested_by, :requested_at).to_h
        entry.request_verification(request_params)
        entry
      end
      action_access :request_verification, :public
      params :verify_params do
        [:payable_id, :payable_type, :accepted, :verified_by, :verified_at]
      end

      action_access :verify, :private
      action :verify do |params, *args|
        payable = params[:payable] ||
        if !payable.class.try(:payable?) && params[:payable_type].present? && params[:payable_id].present?
          payable_class(params[:payable_type]).payable_api.finder(params[:payable_id])
        end

        entry = if payable
          payable.payable_entries
            .with_entry_types(PaymentCore::Entries::Charges::BankTransfer.entry_type)
            .where(payment_method: payment_method)
            .order(created_at: :desc)
            .first
        end

        unless entry
          entry = PaymentCore::Entries::Charges::BankTransfer.new
          entry.errors.add(:base, :not_found)
          next entry
        end

        verification_params = params.slice(:verified_by, :verified_at).to_h
        accepted = ActiveModel::Type::Boolean.new.cast(params[:accepted])

        if accepted
          entry.accept_verification(verification_params)
        else
          entry.reject_verification(verification_params)
        end

        entry
      end


    end
  end
end
