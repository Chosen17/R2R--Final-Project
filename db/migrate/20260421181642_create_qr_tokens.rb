class CreateQrTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :qr_tokens do |t|
      t.references :qr_transaction, null: false, foreign_key: { to_table: :transactions }
      t.string :token
      t.datetime :expires_at
      t.boolean :used

      t.timestamps
    end
  end
end
