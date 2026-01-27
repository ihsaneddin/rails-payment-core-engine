namespace :payment_core do
  namespace :fiuu do
    desc "Create a sandbox charge and wait for webhook to update entry state"
    task charge_and_wait: :environment do
      require "securerandom"
      require "digest/md5"
      Order; LineItem; User; Product; PaymentPackageProductValue
      Product::Item; Product::Service; Product::PaymentPackage

      merchant_id = ENV["FIUU_MERCHANT_ID"]
      secret_key = ENV["FIUU_SECRET_KEY"]
      verify_key = ENV["FIUU_VERIFY_KEY"]
      webhook_host = ENV["APP_HOST"]
      return_path = ENV["FIUU_RETURN_PATH"]
      webhook_path = ENV["FIUU_WEBHOOK_PATH"]
      return_url = if webhook_host.present? && return_path.present?
        "#{webhook_host}#{return_path}"
      end
      callback_url = if webhook_host.present? && webhook_path.present?
        "#{webhook_host}#{webhook_path}"
      end
      notify_url = callback_url

      missing = {
        FIUU_MERCHANT_ID: merchant_id,
        FIUU_SECRET_KEY: secret_key,
        FIUU_VERIFY_KEY: verify_key,
        APP_HOST: webhook_host,
        FIUU_RETURN_PATH: return_path,
        FIUU_WEBHOOK_PATH: webhook_path
      }.select { |_k, v| v.to_s.strip.empty? }
      unless missing.empty?
        abort("Missing env vars: #{missing.keys.join(", ")}")
      end

      user = User.first || User.create!(email: "user@example.com", name: "User")
      product = Product::Item.first || Product::Item.create!(price: 10, name: "Sandbox Item", sku: SecureRandom.hex(4))

      order = Order.create!(customer: user, name: "fiuu-sandbox", state: "cart")
      order.line_item_line_items.create!(item: product, quantity: 1, use_item_data: true)
      order.update!(state: "waiting_payment")
      order.reload

      payment_method = PaymentCore::PaymentMethods::Fiuu.find_or_create_by!(display_name: "Fiuu Sandbox") do |pm|
        pm.active = true
        pm.always_available = true
        pm.metadata_merchant_id = merchant_id
        pm.metadata_secret_key = secret_key
        pm.metadata_verify_key = verify_key
        pm.metadata_return_url = return_url if return_url.present?
        pm.metadata_callback_url = callback_url if callback_url.present?
        pm.metadata_notify_url = notify_url if notify_url.present?
      end

      context = PaymentCore.config.payment_method.availability_context_class_constant.new(
        regions: ["ID"],
        currencies: ["MYR"],
        use_cases: ["checkout"],
        payables: [order]
      )

      entry = payment_method.processor(payer: user, context: context).charge(
        payable: order,
        return_url: return_url
      )

      if entry.errors.any?
        abort("Entry errors: #{entry.errors.full_messages.join(", ")}")
      end

      puts "Entry ID: #{entry.id}"
      puts "Entry number: #{entry.number}"
      puts "Redirect Path: #{entry.metadata.payment_method_data.redirect_path}"
      puts "Redirect URL: #{entry.metadata.payment_method_data.redirect_url}"
      puts "Redirect Payload: #{entry.metadata.payment_method_data.redirect_payload}"
      payload = entry.metadata.payment_method_data.redirect_payload || {}
      base_url = entry.metadata.payment_method_data.redirect_url.to_s
      puts "Redirect GET URL: #{base_url}"
      wait_seconds = (ENV["FIUU_WAIT_SECONDS"] || "60").to_i
      puts "Waiting #{wait_seconds}s before simulating webhook..."
      sleep wait_seconds if wait_seconds.positive?

      status = ENV["FIUU_SIMULATE_STATUS"] || "00"
      tran_id = "TX-#{SecureRandom.hex(6)}"
      paydate = Time.now.strftime("%Y%m%d%H%M%S")
      appcode = "APP-1"
      nbcb = "2"
      domain = merchant_id
      payload = entry.metadata.payment_method_data.redirect_payload || {}
      amount = payload[:amount] || payload["amount"] || entry.amount.to_s
      currency = payload[:currency] || payload["currency"] || entry.currency
      order_id = payload[:orderid] || payload["orderid"] || entry.number

      key0 = Digest::MD5.hexdigest("#{tran_id}#{order_id}#{status}#{domain}#{amount}#{currency}")
      skey = Digest::MD5.hexdigest("#{paydate}#{domain}#{key0}#{appcode}#{secret_key}")

      webhook_params = {
        orderid: order_id,
        tranID: tran_id,
        status: status,
        amount: amount,
        currency: currency,
        paydate: paydate,
        appcode: appcode,
        skey: skey,
        domain: domain,
        nbcb: nbcb
      }

      require "net/http"
      require "uri"
      webhook_url = "#{webhook_host}#{webhook_path}"
      uri = URI.parse(webhook_url)
      req = Net::HTTP::Post.new(uri)
      req["Accept"] = "application/json"
      req["Content-Type"] = "application/x-www-form-urlencoded"
      req.set_form_data(webhook_params)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(req)
      end
      puts "Webhook simulated: #{res.code} #{res.body}"

      entry.reload
      puts "Final state: #{entry.state}"
      puts "payable_transaction_id: #{entry.payable_transaction_id}"
    end
  end
end
