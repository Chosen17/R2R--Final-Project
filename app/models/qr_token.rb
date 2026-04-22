class QrToken < ApplicationRecord
  belongs_to :qr_transaction, class_name: "Transaction", foreign_key: :qr_transaction_id
end
