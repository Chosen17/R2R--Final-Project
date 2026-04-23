class Transaction < ApplicationRecord
  # customer_id is intentionally optional here — a transaction is created
  # when staff upload a receipt, BEFORE any customer has scanned the QR.
  # The customer is linked to the transaction later in the webhook controller
  # when they scan the QR code and message the R2R bot via WhatsApp.
  belongs_to :customer, optional: true

  has_one :qr_token, foreign_key: :qr_transaction_id

  # Enforce uniqueness of receipt_hash at the ActiveRecord level as
  # well as the database UNIQUE index, so duplicates are caught with
  # a clean validation error rather than a raw SQL exception.
  # Prevents the same receipt image being processed twice (FR9).
  validates :receipt_hash, uniqueness: true, presence: true
end
