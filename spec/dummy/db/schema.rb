# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2025_07_20_183103) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "ewallet_accounts", force: :cascade do |t|
    t.bigint "wallet_id"
    t.bigint "currency_id"
    t.string "currency_name"
    t.string "name"
    t.text "description"
    t.string "state"
    t.boolean "limited_time"
    t.datetime "should_expire_at", precision: nil
    t.datetime "active_at", precision: nil
    t.datetime "expired_at", precision: nil
    t.datetime "frozen_at", precision: nil
    t.datetime "inactive_at", precision: nil
    t.datetime "last_amount_changed_at", precision: nil
    t.integer "entries_count"
    t.datetime "deleted_at", precision: nil
    t.boolean "contra", default: false
    t.integer "flags", default: [], null: false, array: true
    t.string "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_id"], name: "index_ewallet_accounts_on_currency_id"
    t.index ["wallet_id"], name: "index_ewallet_accounts_on_wallet_id"
  end

  create_table "ewallet_amounts", force: :cascade do |t|
    t.string "type"
    t.bigint "account_id"
    t.bigint "entry_id"
    t.decimal "amount", precision: 15, scale: 2
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_ewallet_amounts_on_account_id"
    t.index ["entry_id"], name: "index_ewallet_amounts_on_entry_id"
  end

  create_table "ewallet_currencies", force: :cascade do |t|
    t.string "issuer_type"
    t.bigint "issuer_id"
    t.string "reference_type"
    t.bigint "reference_id"
    t.string "name"
    t.string "symbol"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["issuer_type", "issuer_id"], name: "index_ewallet_currencies_on_issuer_type_and_issuer_id"
    t.index ["reference_type", "reference_id"], name: "index_ewallet_currencies_on_reference_type_and_reference_id"
  end

  create_table "ewallet_currency_rates", force: :cascade do |t|
    t.string "name"
    t.decimal "rate"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ewallet_entries", force: :cascade do |t|
    t.string "reference_type"
    t.bigint "reference_id"
    t.bigint "currency_id"
    t.string "currency_name"
    t.string "hash_number"
    t.string "state"
    t.string "description"
    t.date "date"
    t.string "type"
    t.integer "amounts_count"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency_id"], name: "index_ewallet_entries_on_currency_id"
    t.index ["reference_type", "reference_id"], name: "index_ewallet_entries_on_reference_type_and_reference_id"
  end

  create_table "ewallet_issuers", force: :cascade do |t|
    t.string "name"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ewallet_wallets", force: :cascade do |t|
    t.string "holder_type"
    t.bigint "holder_id"
    t.string "issuer_type"
    t.bigint "issuer_id"
    t.string "number"
    t.string "type"
    t.datetime "deleted_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["holder_type", "holder_id"], name: "index_ewallet_wallets_on_holder_type_and_holder_id"
    t.index ["issuer_type", "issuer_id"], name: "index_ewallet_wallets_on_issuer_type_and_issuer_id"
  end

  create_table "order_core_line_item_hierarchies", id: false, force: :cascade do |t|
    t.integer "ancestor_id", null: false
    t.integer "descendant_id", null: false
    t.integer "generations", null: false
  end

  create_table "order_core_line_items", force: :cascade do |t|
    t.bigint "order_id"
    t.string "item_type"
    t.bigint "item_id"
    t.string "store_type"
    t.bigint "store_id"
    t.bigint "parent_id"
    t.bigint "tenant_id"
    t.string "number", limit: 64, null: false
    t.string "state"
    t.text "instructions"
    t.string "channel"
    t.string "platform"
    t.string "token"
    t.string "quantity_unit"
    t.decimal "quantity"
    t.decimal "price", precision: 10, scale: 2
    t.boolean "fixed_price", default: true
    t.string "currency"
    t.boolean "fixed_total_item_amount", default: true
    t.decimal "total_item_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_children_item_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_discount_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_exclusive_tax_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_inclusive_tax_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_tax_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0"
    t.integer "children_count"
    t.jsonb "data"
    t.string "type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_type", "item_id"], name: "index_line_items_on_item"
    t.index ["number"], name: "index_line_items_on_number"
    t.index ["order_id"], name: "index_order_core_line_items_on_order_id"
    t.index ["parent_id"], name: "index_order_core_line_items_on_parent_id"
    t.index ["store_type", "store_id"], name: "index_line_items_on_store"
    t.index ["tenant_id"], name: "index_order_core_line_items_on_tenant_id"
  end

  create_table "order_core_order_hierarchies", id: false, force: :cascade do |t|
    t.integer "ancestor_id", null: false
    t.integer "descendant_id", null: false
    t.integer "generations", null: false
  end

  create_table "order_core_orders", force: :cascade do |t|
    t.string "customer_type"
    t.bigint "customer_id"
    t.string "store_type"
    t.bigint "store_id"
    t.bigint "parent_id"
    t.bigint "tenant_id"
    t.string "name"
    t.text "description"
    t.string "state"
    t.string "customer_identification"
    t.string "number", limit: 64, null: false
    t.text "instructions"
    t.string "channel"
    t.string "platform"
    t.string "token"
    t.string "currency"
    t.boolean "fixed_total_item_amount", default: true
    t.decimal "total_item_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_children_item_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_discount_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_exclusive_tax_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_inclusive_tax_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_tax_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0"
    t.integer "children_count"
    t.integer "line_items_count"
    t.jsonb "data"
    t.string "order_type"
    t.string "type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_type", "customer_id"], name: "index_orders_on_customer"
    t.index ["number"], name: "index_orders_on_number"
    t.index ["parent_id"], name: "index_order_core_orders_on_parent_id"
    t.index ["store_type", "store_id"], name: "index_orders_on_store"
    t.index ["tenant_id"], name: "index_order_core_orders_on_tenant_id"
  end

  create_table "payment_core_billing_statements", force: :cascade do |t|
    t.string "customer_type"
    t.bigint "customer_id"
    t.string "issuer_type"
    t.bigint "issuer_id"
    t.string "number"
    t.text "description"
    t.datetime "period_start"
    t.datetime "period_end"
    t.decimal "total_amount", precision: 15, scale: 2
    t.string "currency"
    t.string "state"
    t.datetime "due_at"
    t.datetime "issued_at"
    t.string "entry_class"
    t.jsonb "metadata", default: {}
    t.string "type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency"], name: "index_payment_core_billing_statements_on_currency"
    t.index ["customer_type", "customer_id"], name: "payment_billing_statements_customer"
    t.index ["deleted_at"], name: "index_payment_core_billing_statements_on_deleted_at"
    t.index ["due_at"], name: "index_payment_core_billing_statements_on_due_at"
    t.index ["issued_at"], name: "index_payment_core_billing_statements_on_issued_at"
    t.index ["issuer_type", "issuer_id"], name: "payment_billing_statements_issuer"
    t.index ["number"], name: "index_payment_core_billing_statements_on_number", unique: true
    t.index ["period_end"], name: "index_payment_core_billing_statements_on_period_end"
    t.index ["period_start"], name: "index_payment_core_billing_statements_on_period_start"
    t.index ["state"], name: "index_payment_core_billing_statements_on_state"
  end

  create_table "payment_core_entries", force: :cascade do |t|
    t.bigint "payment_intent_id"
    t.bigint "payment_method_id"
    t.string "payable_type"
    t.bigint "payable_id"
    t.string "payer_type"
    t.bigint "payer_id"
    t.string "paid_at_type"
    t.bigint "paid_at_id"
    t.string "reference_type"
    t.bigint "reference_id"
    t.bigint "parent_id"
    t.string "idempotency_key"
    t.datetime "idempotency_window"
    t.string "number"
    t.text "description"
    t.string "payable_transaction_id"
    t.boolean "partial", default: false
    t.decimal "payment_method_amount", precision: 15, scale: 2, default: "0.0"
    t.decimal "amount", precision: 15, scale: 2, default: "0.0"
    t.string "currency"
    t.string "direction"
    t.string "state"
    t.datetime "will_expires_at"
    t.datetime "processed_at"
    t.datetime "succeeded_at"
    t.datetime "canceled_at"
    t.datetime "expired_at"
    t.datetime "failed_at"
    t.text "failure_reason"
    t.jsonb "metadata", default: {}
    t.string "type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_payment_core_entries_on_deleted_at"
    t.index ["idempotency_key"], name: "index_payment_core_entries_on_idempotency_key"
    t.index ["paid_at_type", "paid_at_id"], name: "index_payment_core_entries_on_paid_at_type_and_paid_at_id"
    t.index ["parent_id"], name: "index_payment_core_entries_on_parent_id"
    t.index ["payable_type", "payable_id"], name: "index_payment_core_entries_on_payable_type_and_payable_id"
    t.index ["payer_type", "payer_id"], name: "index_payment_core_entries_on_payer_type_and_payer_id"
    t.index ["payment_intent_id"], name: "index_payment_core_entries_on_payment_intent_id"
    t.index ["payment_method_id"], name: "index_payment_core_entries_on_payment_method_id"
    t.index ["reference_type", "reference_id"], name: "index_payment_core_entries_on_reference_type_and_reference_id"
    t.index ["state"], name: "index_payment_core_entries_on_state"
  end

  create_table "payment_core_invoice_items", force: :cascade do |t|
    t.bigint "invoice_id"
    t.string "number"
    t.text "description"
    t.decimal "total_item_amount", precision: 12, scale: 2
    t.decimal "total_discount_amount", precision: 12, scale: 2
    t.decimal "total_exclusive_tax_amount", precision: 12, scale: 2
    t.decimal "total_inclusive_tax_amount", precision: 12, scale: 2
    t.decimal "total_amount", precision: 12, scale: 2
    t.string "currency"
    t.jsonb "metadata", default: {}
    t.string "type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency"], name: "index_payment_core_invoice_items_on_currency"
    t.index ["deleted_at"], name: "index_payment_core_invoice_items_on_deleted_at"
    t.index ["invoice_id", "deleted_at"], name: "index_payment_core_invoice_items_on_invoice_id_and_deleted_at"
    t.index ["invoice_id", "type"], name: "index_payment_core_invoice_items_on_invoice_id_and_type"
    t.index ["number"], name: "index_payment_core_invoice_items_on_number"
    t.index ["type"], name: "index_payment_core_invoice_items_on_type"
  end

  create_table "payment_core_invoices", force: :cascade do |t|
    t.string "customer_type"
    t.bigint "customer_id"
    t.string "billable_type"
    t.bigint "billable_id"
    t.bigint "billing_statement_id"
    t.string "number"
    t.text "description"
    t.decimal "total_item_amount", precision: 12, scale: 2
    t.decimal "total_discount_amount", precision: 12, scale: 2
    t.decimal "total_exclusive_tax_amount", precision: 12, scale: 2
    t.decimal "total_inclusive_tax_amount", precision: 12, scale: 2
    t.decimal "total_amount", precision: 12, scale: 2
    t.string "currency"
    t.string "type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["billable_type", "billable_id", "deleted_at"], name: "index_invoices_on_billable_and_deleted_at"
    t.index ["billing_statement_id", "deleted_at"], name: "index_invoices_on_billing_statement_and_deleted_at"
    t.index ["customer_type", "customer_id", "deleted_at"], name: "index_invoices_on_customer_and_deleted_at"
    t.index ["deleted_at"], name: "index_payment_core_invoices_on_deleted_at"
    t.index ["number"], name: "index_payment_core_invoices_on_number", unique: true
  end

  create_table "payment_core_payment_intents", force: :cascade do |t|
    t.string "payable_type"
    t.bigint "payable_id"
    t.string "gid"
    t.string "reference_id"
    t.decimal "amount", precision: 15, scale: 2, default: "0.0"
    t.string "currency"
    t.string "state"
    t.datetime "expires_at"
    t.datetime "confirmed_at"
    t.string "confirmation_method"
    t.jsonb "metadata", default: {}
    t.string "type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_method"], name: "index_payment_core_payment_intents_on_confirmation_method"
    t.index ["currency"], name: "index_payment_core_payment_intents_on_currency"
    t.index ["deleted_at"], name: "index_payment_core_payment_intents_on_deleted_at"
    t.index ["gid"], name: "index_payment_core_payment_intents_on_gid", unique: true
    t.index ["payable_type", "payable_id"], name: "payment_core_intents_payable"
    t.index ["reference_id"], name: "index_payment_core_payment_intents_on_reference_id"
    t.index ["state"], name: "index_payment_core_payment_intents_on_state"
  end

  create_table "payment_core_payment_methods", force: :cascade do |t|
    t.string "holder_type"
    t.bigint "holder_id"
    t.string "reference_type"
    t.bigint "reference_id"
    t.string "number"
    t.string "display_name"
    t.boolean "use_reference"
    t.string "method_type"
    t.string "external_provider"
    t.string "setup_intent_id"
    t.boolean "default", default: false
    t.boolean "active", default: true
    t.boolean "always_available", default: true
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.datetime "provisioned_at"
    t.datetime "last_failed_at"
    t.string "failure_reason"
    t.string "currency"
    t.jsonb "metadata", default: {}
    t.jsonb "availability_rules", default: {}
    t.datetime "deleted_at"
    t.integer "entries_count"
    t.string "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_payment_core_payment_methods_on_deleted_at"
    t.index ["external_provider"], name: "index_payment_core_payment_methods_on_external_provider"
    t.index ["holder_type", "holder_id"], name: "index_payment_core_payment_methods_on_holder_type_and_holder_id"
    t.index ["method_type"], name: "index_payment_core_payment_methods_on_method_type"
    t.index ["reference_type", "reference_id"], name: "payment_core_methods_reference"
  end

  create_table "payment_package_product_values", force: :cascade do |t|
    t.bigint "product_id"
    t.bigint "payment_package_id"
    t.decimal "value", default: "1.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_package_id"], name: "index_payment_package_product_values_on_payment_package_id"
    t.index ["product_id"], name: "index_payment_package_product_values_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.string "sku"
    t.decimal "price", precision: 12, scale: 2
    t.string "unit_quantity", default: "unit"
    t.decimal "quantity", precision: 8, scale: 2, default: "0.0"
    t.jsonb "data"
    t.string "type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.string "phone_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
