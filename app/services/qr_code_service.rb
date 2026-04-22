# QrCodeService
# This service generates a secure QR code for a given transaction.
# It creates a cryptographically random token, stores it in the
# database with a 24-hour expiry, builds a WhatsApp deep link URL
# that the customer will land on when they scan the QR code, and
# renders the QR code as a Base64-encoded PNG for display in the browser.
class QrCodeService
  # Store the transaction when the service is created
  def initialize(transaction)
    @transaction = transaction
  end

  # Main entry point — called from the TransactionsController after
  # a receipt has been processed. Returns the saved QrToken record,
  # which includes the Base64 PNG for display.
  def call
    # Generate a cryptographically secure random token (256-bit).
    # urlsafe_base64 ensures the token is safe to use in a URL.
    token = SecureRandom.urlsafe_base64(32)

    # Build the URL that the QR code will encode.
    # When scanned, this takes the customer to a redirect page which
    # then opens WhatsApp with a pre-populated message to the R2R bot.
    qr_url = "#{base_url}/r/#{token}"

    # Generate the QR code image from the URL using the rqrcode gem.
    # Size 500 gives a high enough resolution for printing on receipts.
    qr = RQRCode::QRCode.new(qr_url)
    png = qr.as_png(size: 500)

    # Encode the PNG as a Base64 data URI so it can be embedded
    # directly in an HTML img tag without needing to save it as a file
    png_base64 = "data:image/png;base64,#{Base64.strict_encode64(png.to_s)}"

    # Save the QR token record to the database.
    # expires_at: 24 hours from now — after this the token is invalid
    # used: false — becomes true after the customer scans it once
    QrToken.create!(
      qr_transaction_id: @transaction.id,
      token: token,
      expires_at: 24.hours.from_now,
      used: false,
      qr_png_base64: png_base64
    )
  end

  private

  # Returns the base URL for building the QR code link.
  # In development this is localhost — in production it would be
  # the live server URL stored in an environment variable.
  def base_url
    Rails.env.development? ? "http://localhost:3000" : ENV["APP_BASE_URL"]
  end
end
