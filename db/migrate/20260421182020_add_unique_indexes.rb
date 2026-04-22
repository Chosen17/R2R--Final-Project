class AddUniqueIndexes < ActiveRecord::Migration[8.0]
  def change
  add_index :customers, :phone_number, unique: true
  add_index :transactions, :receipt_hash, unique: true
  add_index :qr_tokens, :token, unique: true
  end
end
