class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :customer, null: true, foreign_key: true
      t.string :receipt_hash
      t.decimal :bill_total
      t.decimal :cashback_amount
      t.boolean :redeemed

      t.timestamps
    end
  end
end
