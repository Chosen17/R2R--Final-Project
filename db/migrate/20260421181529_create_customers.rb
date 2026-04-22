class CreateCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :customers do |t|
      t.string :phone_number
      t.string :name
      t.decimal :cashback_balance
      t.string :conversation_state
      t.datetime :last_message_at

      t.timestamps
    end
  end
end
