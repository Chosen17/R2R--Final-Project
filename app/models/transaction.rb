class Transaction < ApplicationRecord
  belongs_to :customer  #the customer can have many transactions, but each transaction belongs to one customer (entity relationship)
  has_one :qr_token, foreign_key: :qr_transaction_id        #each transaction produced one qr code and that qr code is tied to only that transcation with that amount.
end
