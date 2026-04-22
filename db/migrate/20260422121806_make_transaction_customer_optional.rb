class MakeTransactionCustomerOptional < ActiveRecord::Migration[8.0]
def change
  # Allow transactions to exist without a customer initially.
  # A customer is linked later when they scan the QR code.
  change_column_null :transactions, :customer_id, true
end
end
