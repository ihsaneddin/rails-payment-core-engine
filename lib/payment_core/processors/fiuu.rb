require "json"

module PaymentCore
  module Processors
    class Fiuu < Base

      self.method_type = "fiuu"

      params :charge_params do
        [
          :payable_id,
          :payable_type,
          :payable,
          :return_url
        ]
      end

      action :charge do |params, *args|
        payable = params[:payable] ||
          if params[:payable_type].present? && params[:payable_id].present?
            payable_class(params[:payable_type]).payable_api.finder(params[:payable_id])
          end

        if payment_method.require_intent? && payable&.active_payable_payment_intent.blank?
          entry = PaymentCore::Entries::Charge.new
          entry.errors.add(:payment_intent_id, :required)
          next entry
        end

        unless payable
          entry = PaymentCore::Entries::Charge.new
          entry.errors.add(:payable, :required)
          next entry
        end

        amount = payable.payable_unpaid_amount
        currency = payable.payable_currency
        payment_method_amount = payable.payable_to_payment_method_amount(payment_method, amount)

        metadata = build_entry_metadata(params: params, payable: payable)
        entry = build_charge_entry(
          payable: payable,
          amount: amount,
          payment_method_amount: payment_method_amount,
          currency: currency,
          description: params[:description],
          metadata: metadata
        )

        method_data = ensure_method_data(entry.metadata)
        method_data.order_id ||= entry.number

        apply_flow(
          entry: entry,
          method_data: method_data,
          amount: payment_method_amount || amount,
          currency: currency,
          description: params[:description]
        )

        entry
      end

      action_access :charge, :public

      params :status_params do
        [:entry_id]
      end

      action :status do |params, *args|
        entry = params[:entry] || (params[:entry_id] && PaymentCore::Entry.find_by(id: params[:entry_id]))
        entry
      end

      action_access :status, :public

      params :check_status_params do
        [:entry_id]
      end

      action :check_status do |params, *args|
        entry = ::PaymentCore::Entry
          .joins(:payment_method)
          .where(payment_core_payment_methods: { method_type: "fiuu" })
          .find_by(id: params[:entry_id])
        raise ::ActiveRecord::RecordNotFound unless entry

        unless final_entry_state?(entry)
          method_data = ensure_method_data(entry.metadata)
          order_id = method_data.order_id || entry.number
          transaction_id = method_data.transaction_id || entry.payable_transaction_id
          amount = entry.payment_method_amount.presence || entry.amount
          response = entry.payment_method.gateway.entry_info(
            order_id: order_id,
            transaction_id: transaction_id,
            amount: amount,
            verify_key: entry.payment_method.metadata_verify_key
          )
          apply_status_payload(entry: entry, payload: response, gateway_response: response)
        end

        entry
      end

      action_access :check_status, :public

      webhook_action :capture do |params, *args|
        entry = params[:entry]
        raise ::ActiveRecord::RecordNotFound unless entry

        payload = params[:webhook_payload] || (params.to_h if params.respond_to?(:to_h)) || {}
        method_data = ensure_method_data(entry.metadata)
        method_data.last_webhook_attempt_at = Time.current
        apply_status_payload(entry: entry, payload: payload)
        entry.save if entry.changed?
        entry
      end

      action_access :capture, :public_webhook, prefix: :webhook

      params :capture_params, type: :webhook do
        [
          :orderid,
          :tranID,
          :status,
          :amount,
          :currency,
          :paydate,
          :appcode,
          :skey,
          :domain
        ]
      end

      private

      def build_entry_metadata(params:, payable:)
        metadata = params[:metadata]
        metadata =
          if metadata.respond_to?(:to_h)
            metadata.to_h
          else
            {}
          end
        metadata = metadata.deep_symbolize_keys if metadata.respond_to?(:deep_symbolize_keys)
        payment_method_data = metadata[:payment_method_data]
        payment_method_data =
          if payment_method_data.respond_to?(:attributes)
            payment_method_data.attributes
          elsif payment_method_data.respond_to?(:to_h)
            payment_method_data.to_h
          elsif payment_method_data.is_a?(Hash)
            payment_method_data
          else
            {}
          end
        if metadata[:payment_method_data].nil?
          metadata[:payment_method_data] = payment_method_data
        end
        payment_method_data = payment_method_data.deep_symbolize_keys if payment_method_data.respond_to?(:deep_symbolize_keys)
        payment_method_data[:method_type] = payment_method.method_type
        payment_method_data[:flow] ||= payment_method.metadata_flow
        payable_data = payable.payable_config.entry_requirements.try(:fiuu_charge_payment_method_data) || {}
        payable_data = payable_data.to_h if payable_data.respond_to?(:to_h)
        payment_method_data[:bill_name] ||= payable_data[:name] || payable_data["name"]
        payment_method_data[:bill_email] ||= payable_data[:email] || payable_data["email"]
        payment_method_data[:bill_phone] ||= payable_data[:phone] || payable_data["phone"]
        payment_method_data[:country] ||= payable_data[:country] || payable_data["country"]
        payment_method_data[:bill_name] ||= payer.respond_to?(:name) ? payer.name : nil
        payment_method_data[:bill_email] ||= payer.respond_to?(:email) ? payer.email : nil
        payment_method_data[:bill_phone] ||= if payer.respond_to?(:phone)
          payer.phone
        elsif payer.respond_to?(:phone_number)
          payer.phone_number
        end
        payment_method_data[:bill_mobile] ||= payment_method_data[:bill_phone]
        payment_method_data[:return_url] ||= params[:return_url] || payment_method.metadata_return_url
        payment_method_data[:callback_url] ||= payment_method.metadata_callback_url
        payment_method_data[:notify_url] ||= payment_method.metadata_notify_url
        metadata[:payment_method_data] = payment_method_data
        metadata
      end

      def build_charge_entry(payable:, amount:, payment_method_amount:, currency:, description:, metadata:)
        entry = PaymentCore::Entries::Charge.new(
          payment_intent: payable&.active_payable_payment_intent,
          payment_method: payment_method,
          payer: payer,
          payable: payable,
          amount: amount,
          payment_method_amount: payment_method_amount,
          currency: currency,
          description: description,
          context: context,
          metadata: metadata
        )
        entry.number = SecureRandom.hex(12) if entry.number.blank?
        entry
      end

      def apply_redirect_flow(entry:, method_data:, amount:, currency:, description:)
        gateway = payment_method.gateway
        payload, payload_meta = gateway.build_redirect_payload(
          payment_method_data: method_data,
          amount: amount,
          currency: currency,
          description: description,
          verify_key: payment_method.metadata_verify_key
        )
        gateway_path = gateway.redirect_path(
          method_data,
          enabled_channels: payment_method.enabled_channel_codes
        )
        method_data.redirect_path = gateway_path
        method_data.redirect_payload = payload
        method_data.redirect_url = if gateway_path.present?
          query = payload.present? ? URI.encode_www_form(payload) : ""
          url = gateway.build_url(gateway_path)
          query.present? ? "#{url}?#{query}" : url
        end
        apply_redirect_flow_payload(method_data, response: nil, payload: payload, payload_meta: payload_meta)
        entry.save
      end

      def apply_flow(entry:, method_data:, amount:, currency:, description:)
        case method_data.flow.to_s
        when "direct"
          apply_direct_flow(entry: entry, method_data: method_data, amount: amount, currency: currency, description: description)
        when "redirect", ""
          apply_redirect_flow(
            entry: entry,
            method_data: method_data,
            amount: amount,
            currency: currency,
            description: description
          )
        end
      end

      def apply_direct_flow(entry:, method_data:, amount:, currency:, description:)
        raise ::PaymentCore::Errors::ProcessorActionNotAllowed, "Fiuu direct flow is not supported yet"
      end

      def apply_redirect_flow_payload(method_data, response:, payload: nil, payload_meta: nil)
        method_data.gateway_request = payload if payload.present?
        payload = payload.deep_symbolize_keys if payload.respond_to?(:deep_symbolize_keys)
        payload_meta = payload_meta.deep_symbolize_keys if payload_meta.respond_to?(:deep_symbolize_keys)
        method_data.order_id ||= payload && payload[:orderid]
        method_data.vcode ||= payload && payload[:vcode]
        method_data.order_id ||= payload_meta && payload_meta[:order_id]
        method_data.vcode ||= payload_meta && payload_meta[:vcode]
        if response
          normalized = payment_method.gateway.normalize_response(response)
          method_data.gateway_response = normalized
          method_data.status ||= normalized[:status]
          method_data.redirect_url ||= normalized[:redirect_url] || normalized[:payment_url]
        end
      end

      def ensure_method_data(metadata)
        data = metadata.payment_method_data
        return data if data

        metadata.payment_method_data = {
          method_type: payment_method.method_type,
          flow: payment_method.metadata_flow
        }
        metadata.payment_method_data
      end


      def apply_status_payload(entry:, payload:, gateway_response: nil)
        method_data = ensure_method_data(entry.metadata)
        method_data.webhook_payload = payload if gateway_response.nil?
        method_data.gateway_response = gateway_response if gateway_response
        method_data.status ||= payload[:status] || payload[:StatCode] || payload[:statcode]
        method_data.transaction_id ||= payload[:tranID] || payload[:TranID] || payload[:transaction_id] || payload[:tranid]
        method_data.order_id ||= payload[:orderid] || payload[:OrderID] || payload[:order_id] || method_data.order_id
        method_data.skey ||= payload[:skey] || payload[:SKey] || payload[:sKey]
        entry.payable_transaction_id ||= method_data.transaction_id

        status = method_data.status.to_s.strip
        transitioned = false
        case status
        when "00"
          transitioned = entry.success
        when "11"
          transitioned = entry.failure
        when "22"
          transitioned = entry.process
        end

        entry.save if entry.changed? && !transitioned
      end

      def final_entry_state?(entry)
        %w[succeeded failed canceled expired reversed disputed].include?(entry.state.to_s)
      end

    end
  end
end
