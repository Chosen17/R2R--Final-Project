class FixDecimalPrecision < ActiveRecord::Migration[8.0]
  def change
    # this is here to ensure that the bills and the total check are stored corrected
    # to 2 decimal places, which is important for money values to avoid rounding issues
    # for example - if the OCR extracts a total of 10.999, we want to store it as 10.99 not 10.999
    change_column :transactions, :bill_total, :decimal, precision: 8, scale: 2
    change_column :transactions, :cashback_amount, :decimal, precision: 8, scale: 2
    change_column :customers, :cashback_balance, :decimal, precision: 8, scale: 2
  end
end
