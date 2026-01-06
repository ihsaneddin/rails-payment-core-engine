class RemoveIdempotencyKeyIndex < ActiveRecord::Migration[7.0]
  def change
    remove_index :payment_core_entries, column: [:idempotency_key], unique: true
    add_index :payment_core_entries, :idempotency_key
  end
end
