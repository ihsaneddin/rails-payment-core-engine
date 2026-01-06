class CreateProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :products do |t|
      t.string :name
      t.string :sku
      t.decimal :price, precision: 12, scale: 2
      t.string :unit_quantity, default: "unit"
      t.decimal :quantity, default: 0, precision: 8, scale: 2
      t.jsonb :data
      t.string :type
      t.timestamps
    end
  end
end
