class CreateOrderCoreTables < ActiveRecord::Migration[7.0]
  def change

    create_table :order_core_orders do |t|
      t.references :customer, polymorphic: true, index: false
      t.references :store, polymorphic: true, index: false
      t.references :parent, index: false
      t.references :tenant, index: false

      t.string :name
      t.text :description
      t.string :state
      t.string :customer_identification
      t.string :number, limit: 64, null: false

      t.text :instructions
      t.string :channel
      t.string :platform
      t.string :token

      t.string :currency
      t.boolean :fixed_total_item_amount, default: true
      t.decimal :total_item_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_children_item_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_discount_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_exclusive_tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_inclusive_tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_amount, precision: 10, scale: 2, default: 0

      t.integer :children_count
      t.integer :line_items_count
      t.jsonb :data
      t.string :order_type

      t.string :type
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :order_core_orders, [:customer_type, :customer_id], name: "index_orders_on_customer"
    add_index :order_core_orders, [:store_type, :store_id], name: "index_orders_on_store"
    add_index :order_core_orders, :parent_id
    add_index :order_core_orders, :tenant_id
    add_index :order_core_orders, :number, name: "index_orders_on_number"

    create_table :order_core_order_hierarchies, id: false do |t|
      t.integer :ancestor_id, null: false
      t.integer :descendant_id, null: false
      t.integer :generations, null: false
    end

    create_table :order_core_line_items do |t|
      t.references :order, index: false
      t.references :item, polymorphic: true, index: false
      t.references :store, polymorphic: true, index: false
      t.references :parent, index: false
      t.references :tenant, index: false

      t.string :number, limit: 64, null: false
      t.string :state

      t.text :instructions
      t.string :channel
      t.string :platform
      t.string :token

      t.string :quantity_unit
      t.decimal :quantity
      t.decimal :price, precision: 10, scale: 2
      t.boolean :fixed_price, default: true

      t.string :currency
      t.boolean :fixed_total_item_amount, default: true
      t.decimal :total_item_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_children_item_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_discount_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_exclusive_tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_inclusive_tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_tax_amount, precision: 10, scale: 2, default: 0
      t.decimal :total_amount, precision: 10, scale: 2, default: 0

      t.integer :children_count
      t.jsonb :data

      t.string :type
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :order_core_line_items, :order_id
    add_index :order_core_line_items, [:item_type, :item_id], name: "index_line_items_on_item"
    add_index :order_core_line_items, [:store_type, :store_id], name: "index_line_items_on_store"
    add_index :order_core_line_items, :parent_id
    add_index :order_core_line_items, :tenant_id
    add_index :order_core_line_items, :number, name: "index_line_items_on_number"

    create_table :order_core_line_item_hierarchies, id: false do |t|
      t.integer :ancestor_id, null: false
      t.integer :descendant_id, null: false
      t.integer :generations, null: false
    end

  end
end