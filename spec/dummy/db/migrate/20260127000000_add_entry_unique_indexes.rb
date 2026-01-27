class AddEntryUniqueIndexes < ActiveRecord::Migration[7.0]
  def change
    add_index :payment_core_entries, :number, unique: true, where: "number IS NOT NULL"
    add_index :payment_core_entries, :payable_transaction_id, unique: true, where: "payable_transaction_id IS NOT NULL"
  end
end
