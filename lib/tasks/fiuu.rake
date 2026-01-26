namespace :payment_core do
  namespace :fiuu do
    desc "Create a sandbox charge and wait for webhook to update entry state"
    task charge_and_wait: :environment do
      require "securerandom"
      Order; LineItem; User; Product; PaymentPackageProductValue
      Product::Item; Product::Service; Product::PaymentPackage

    merchant_id = ENV["FIUU_MERCHANT_ID"]
    secret_key = ENV["FIUU_SECRET_KEY"]
    verify_key = ENV["FIUU_VERIFY_KEY"]
    return_url = ENV["FIUU_RETURN_URL"]
    callback_url = ENV["FIUU_CALLBACK_URL"]
    notify_url = ENV["FIUU_NOTIFY_URL"]

    missing = {
      FIUU_MERCHANT_ID: merchant_id,
      FIUU_SECRET_KEY: secret_key,
      FIUU_VERIFY_KEY: verify_key
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
      currencies: ["RM"],
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
    puts "Redirect URL: #{entry.metadata.payment_method_data.redirect_url}"
    puts "Redirect Payload: #{entry.metadata.payment_method_data.redirect_payload}"
    begin
      payload = entry.metadata.payment_method_data.redirect_payload || {}
      action = entry.metadata.payment_method_data.redirect_url
      html_path = File.expand_path("../../spec/dummy/tmp/fiuu_redirect_#{entry.number}.html", __dir__)
      form_inputs = payload.map do |key, value|
        %(<input type="hidden" name="#{key}" value="#{value}">)
      end.join("\n    ")
      html = <<~HTML
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8">
            <title>Fiuu Redirect</title>
          </head>
          <body>
            <form id="fiuu-redirect" method="POST" action="#{action}">
              #{form_inputs}
            </form>
            <script>
              document.getElementById("fiuu-redirect").submit();
            </script>
          </body>
        </html>
      HTML
      File.write(html_path, html)
      puts "HTML form written to: #{html_path}"
    rescue => e
      warn "Failed to write HTML form: #{e.message}"
    end
    puts "Waiting for webhook update..."

    timeout_seconds = (ENV["FIUU_WAIT_TIMEOUT"] || "300").to_i
    start = Time.now
    loop do
      entry.reload
      break unless entry.state.to_s == "pending"
      if (Time.now - start) > timeout_seconds
        abort("Timed out waiting for webhook. Current state: #{entry.state}")
      end
      sleep 2
    end

    puts "Final state: #{entry.state}"
    puts "payable_transaction_id: #{entry.payable_transaction_id}"
    end
  end
end
