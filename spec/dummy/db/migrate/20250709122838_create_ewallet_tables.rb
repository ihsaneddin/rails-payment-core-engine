class CreateEwalletTables < ActiveRecord::Migration[6.0]
  def change

    create_table :ewallet_wallets do |t|
      t.references :holder, polymorphic: true
      t.references :issuer, polymorphic: true
      t.string :number
      t.string :type
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :ewallet_accounts do |t|
      t.references :wallet, index: true
      t.references :currency, index: true
      t.string :currency_name
      t.string :name
      t.text :description
      t.string :state
      t.boolean :limited_time
      t.datetime :should_expire_at
      t.datetime :active_at
      t.datetime :expired_at
      t.datetime :frozen_at
      t.datetime :inactive_at
      t.datetime :last_amount_changed_at
      t.integer :entries_count
      t.datetime :deleted_at
      t.boolean :contra, default: false
      t.integer :flags, array: true, null: false, default: []
      t.string :type
      t.timestamps
    end

    create_table :ewallet_amounts do |t|
      t.string :type
      t.references :account, index: true
      t.references :entry, index: true
      t.decimal :amount, :precision => 15, :scale => 2
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :ewallet_entries do |t|
      t.references :reference, index: true, polymorphic: true
      t.references :currency, index: true
      t.string :currency_name
      t.string :hash_number
      t.string :txid
      t.string :state
      t.string :description
      t.date :date
      t.string :type
      t.integer :amounts_count
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :ewallet_currency_rates do |t|
      t.string :name
      t.decimal :rate
      t.timestamps
    end

    create_table :ewallet_issuers do |t|
      t.string :name
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :ewallet_currencies do |t|
      t.references :issuer, polymorphic: true, index: true
      t.references :reference, index: true, polymorphic: true
      t.string :name
      t.string :symbol
      t.datetime :deleted_at
      t.timestamps
    end

  end
end
