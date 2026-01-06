class PaymentPackageProductValues < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_package_product_values do |t|
      t.references :product, index: true
      t.references :payment_package, index: true
      t.decimal :value, default: 1
      t.timestamps
    end
  end
end
