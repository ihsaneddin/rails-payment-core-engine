require "json"
require "digest"
require "securerandom"
require "httparty"

module PaymentCore
  module Gateways
    class Fiuu
      DEFAULT_TIMEOUT = 15
      DEFAULT_OPEN_TIMEOUT = 5

      include ::PaymentCore::Gateways::Object

      add_config :api_base_url
      add_config :mode
      add_config :webhook_payload_filter

      configure(
        timeout: DEFAULT_TIMEOUT,
        open_timeout: DEFAULT_OPEN_TIMEOUT,
        base_url: proc { Rails.env.production? ? "https://pay.fiuu.com" : "https://sandbox-payment.fiuu.com" },
        api_base_url: proc { Rails.env.production? ? "https://api.fiuu.com" : "https://sandbox-api.fiuu.com" },
        mode: proc { Rails.env.production? ? "production" : "sandbox" },
        webhook_payload_filter: proc { |params|
          raw = params.respond_to?(:to_h) ? params.to_h : {}
          allowed = %w[orderid tranID status amount currency paydate appcode skey domain nbcb]
          raw.each_with_object({}) do |(key, value), acc|
            k = key.to_s
            acc[k] = value if allowed.include?(k)
          end
        },
        webhook_response: proc { |opts = {}|
          entry = opts[:entry]
          if entry&.payment_method&.metadata_ipn_enabled
            "CBTOKEN:MPSTATOK"
          else
            { status: "ok" }
          end
        },
        entry_resolver: proc { |params|
          order_number = params[:orderid] || params[:order_id]
          entry = order_number.present? ? ::PaymentCore::Entry.find_by(number: order_number) : nil
          if entry.nil?
            tx_id = params[:tranID] || params[:transaction_id]
            entry = tx_id.present? ? ::PaymentCore::Entry.find_by(payable_transaction_id: tx_id) : nil
          end
          next nil unless entry
          next nil unless entry.payment_method&.method_type.to_s == "fiuu"

          valid = entry.payment_method.gateway.verify_webhook_signature(
            params,
            secret_key: entry.payment_method.metadata_secret_key,
            merchant_id: entry.payment_method.metadata_merchant_id
          )
          valid ? entry : nil
        },
        signature_fields: nil,
        signature_builder: nil
      )

      attr_reader :merchant_id, :secret_key, :base_url, :api_base_url, :timeout, :open_timeout, :logger,
                  :signature_fields

      def initialize(merchant_id:, secret_key:, base_url: nil, timeout: nil, open_timeout: nil,
                     logger: nil, signature_fields: nil)
        @merchant_id = merchant_id
        @secret_key = secret_key
        @base_url = base_url || config_base_url || base_url_for_mode(config_mode)
        @api_base_url = config_api_base_url
        @timeout = timeout || config_timeout || DEFAULT_TIMEOUT
        @open_timeout = open_timeout || config_open_timeout || DEFAULT_OPEN_TIMEOUT
        @logger = logger
        @signature_fields = signature_fields || config_signature_fields
      end

      def post_form(path, params:, headers: {})
        request(:post, path, params: params, headers: headers, content_type: "application/x-www-form-urlencoded")
      end

      def post_json(path, payload:, headers: {})
        body = JSON.generate(payload || {})
        request(:post, path, raw_body: body, headers: headers, content_type: "application/json")
      end

      def get(path, params: {}, headers: {})
        request(:get, path, params: params, headers: headers)
      end

      def sign_params(params, signature_key: "skey")
        return params unless signature_needed?
        params = params.dup
        params[signature_key] = build_signature(params)
        params
      end

      def verify_signature(params, signature_key: "skey")
        given = params[signature_key] || params[signature_key.to_sym]
        return false if given.nil?
        expected = build_signature(params)
        secure_compare(given.to_s, expected.to_s)
      end

      def build_redirect_payload(payment_method_data:, amount:, currency:, description:, verify_key:)
        method_data_hash = normalize_method_data(payment_method_data)
        amount = format_amount(amount)
        order_id = method_data_hash[:order_id]
        use_extended = method_data_hash[:extended_vcode].present? || method_data_hash[:mp_extended_vcode].present?
        raise "order_id is required for vcode" if order_id.blank?
        vcode_seed = "#{amount}#{merchant_id}#{order_id}"
        vcode_seed = "#{vcode_seed}#{currency}" if use_extended
        vcode = Digest::MD5.hexdigest("#{vcode_seed}#{verify_key}")

        payload = {
          MerchantID: merchant_id,
          amount: amount,
          orderid: order_id,
          bill_name: method_data_hash[:bill_name],
          bill_email: method_data_hash[:bill_email],
          bill_mobile: method_data_hash[:bill_mobile] || method_data_hash[:bill_phone],
          bill_desc: method_data_hash[:bill_desc] || description,
          country: method_data_hash[:country] || currency,
          vcode: vcode,
          currency: currency,
          returnurl: method_data_hash[:return_url],
          callbackurl: method_data_hash[:callback_url],
          notifyurl: method_data_hash[:notify_url]
        }.compact
        payload[:mp_extended_vcode] = 1 if use_extended
        [payload, { order_id: order_id, vcode: vcode }]
      end

      def redirect_path(payment_method_data, enabled_channels: nil)
        # method_data_hash = normalize_method_data(payment_method_data)
        # code = method_data_hash[:payment_method_code].presence
        # if code.blank? && enabled_channels.present?
        #   codes = Array(enabled_channels).compact
        #   code = codes.length == 1 ? codes.first : "ALL"
        # end
        # code ||= "ALL"
        # "/RMS/pay/#{merchant_id}/#{code}"
        "/RMS/pay/#{merchant_id}/"
      end

      def status_payload(payment_method_data)
        method_data_hash = normalize_method_data(payment_method_data)
        order_id = method_data_hash[:order_id]
        transaction_id = method_data_hash[:transaction_id]
        transaction_id.present? ? { txID: transaction_id } : { orderid: order_id }
      end

      def status_path(payload)
        payload&.key?(:txID) ? "/RMS/query/q_by_tid.php" : "/RMS/query/q_by_oid.php"
      end

      def entry_info(order_id: nil, transaction_id: nil, amount:, verify_key:, type: 2)
        raise ArgumentError, "order_id or transaction_id is required" if order_id.blank? && transaction_id.blank?
        raise ArgumentError, "amount is required" if amount.blank?
        raise ArgumentError, "verify_key is required" if verify_key.blank?

        amount = format_amount(amount)

        if transaction_id.present?
          skey = Digest::MD5.hexdigest("#{transaction_id}#{merchant_id}#{verify_key}#{amount}")
          params = {
            amount: amount,
            txID: transaction_id,
            domain: merchant_id,
            skey: skey,
            type: type
          }.compact
          response = post_form(api_url("/RMS/q_by_tid.php"), params: params)
        else
          skey = Digest::MD5.hexdigest("#{order_id}#{merchant_id}#{verify_key}#{amount}")
          params = {
            amount: amount,
            oID: order_id,
            domain: merchant_id,
            skey: skey,
            type: type
          }.compact
          response = post_form(api_url("/RMS/query/q_by_oid.php"), params: params)
        end

        normalize_response(response)
      end

      def verify_webhook_signature(params, secret_key:, merchant_id:)
        skey = params[:skey] || params[:SKey] || params[:sKey]
        return false if skey.blank?

        amount = format_amount(params[:amount] || params[:Amount])
        tran_id = params[:tranID] || params[:TranID] || params[:transaction_id]
        order_id = params[:orderid] || params[:OrderID] || params[:order_id]
        status = params[:status] || params[:Status]
        domain = params[:domain] || params[:Domain]
        appcode = params[:appcode] || params[:AppCode] || ""
        paydate = params[:paydate] || params[:PayDate] || ""
        currency = params[:currency] || params[:Currency] || ""
        required = [amount, tran_id, order_id, status, domain, paydate, currency]
        return false if required.any? { |value| value.blank? }

        pre_skey = Digest::MD5.hexdigest("#{tran_id}#{order_id}#{status}#{domain}#{amount}#{currency}")
        expected = Digest::MD5.hexdigest("#{paydate}#{domain}#{pre_skey}#{appcode}#{secret_key}")
        expected.to_s == skey.to_s
      end


      def normalize_response(response)
        return response if response.is_a?(Hash)

        data = if response.respond_to?(:parsed_response) && response.parsed_response
          response.parsed_response
        else
          body = response.respond_to?(:body) ? response.body : response.to_s
          begin
            JSON.parse(body)
          rescue JSON::ParserError
            { error: "invalid_json", raw: body }
          end
        end
        data = { raw: data } unless data.is_a?(Hash)
        data = data.deep_symbolize_keys if data.respond_to?(:deep_symbolize_keys)
        data[:http_code] ||= response.code if response.respond_to?(:code)
        data
      end

      def build_signature(params)
        resolved = config_signature_builder(params, secret_key)
        return resolved if resolved.present?
        return nil if signature_fields.nil?

        payload = signature_fields.map { |key| params[key] || params[key.to_s] || params[key.to_sym] }.join
        Digest::MD5.hexdigest("#{payload}#{secret_key}")
      end

      def base_url_for_mode(mode)
        mode.to_s == "production" ? "https://pay.fiuu.com" : "https://sandbox-payment.fiuu.com"
      end

      def signature_needed?
        (signature_fields && !signature_fields.empty?)
      end

      def request(method, path, params: nil, raw_body: nil, headers: {}, content_type: nil)
        url = build_url(path)
        options = {
          headers: build_headers(headers, content_type),
          timeout: timeout,
          open_timeout: open_timeout
        }

        begin
          case method.to_s.downcase
          when "post"
            options[:body] = raw_body || params
            log_request(method, url)
            response = HTTParty.post(url, options)
          when "put"
            options[:body] = raw_body || params
            log_request(method, url)
            response = HTTParty.put(url, options)
          when "patch"
            options[:body] = raw_body || params
            log_request(method, url)
            response = HTTParty.patch(url, options)
          when "delete"
            options[:query] = params if params && !params.empty?
            log_request(method, url)
            response = HTTParty.delete(url, options)
          else
            options[:query] = params if params && !params.empty?
            log_request(method, url)
            response = HTTParty.get(url, options)
          end
        rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
          return { error: "timeout", message: e.message, exception: e.class.name }
        end

        log_response(response)
        response
      end

      def build_url(path)
        return path.to_s if path.to_s.start_with?("http")
        base = base_url.to_s
        base = "#{base}/" unless base.end_with?("/")
        "#{base}#{path}".gsub(%r{/+}, "/").sub(":/", "://")
      end

      def api_url(path)
        return path.to_s if path.to_s.start_with?("http")
        base = api_base_url.to_s
        base = "#{base}/" unless base.end_with?("/")
        "#{base}#{path}".gsub(%r{/+}, "/").sub(":/", "://")
      end


      def build_headers(headers, content_type)
        headers = headers.dup
        headers["Content-Type"] = content_type if content_type
        headers
      end

      def log_request(method, uri)
        return unless logger
        logger.info("[Fiuu] #{method.to_s.upcase} #{uri}")
      end

      def log_response(response)
        return unless logger
        logger.info("[Fiuu] response=#{response.code}")
      end

      def secure_compare(a, b)
        return false if a.bytesize != b.bytesize
        l = a.unpack("C*")
        r = b.unpack("C*")
        result = 0
        l.zip(r) { |x, y| result |= x ^ y }
        result.zero?
      end

      def format_amount(amount)
        amount = amount.to_d if amount.respond_to?(:to_d)
        format("%.2f", amount.to_f)
      end

      def normalize_method_data(data)
        return {} if data.nil?
        if data.respond_to?(:attributes)
          data.attributes.deep_symbolize_keys rescue data.attributes
        elsif data.is_a?(Hash)
          data.deep_symbolize_keys
        elsif data.respond_to?(:to_h)
          data.to_h.deep_symbolize_keys rescue data.to_h
        else
          {}
        end
      end
    end
  end
end
