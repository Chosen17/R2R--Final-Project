# QrRedirectsController
# Handles the URL that is encoded inside each QR code.
# When a customer scans the QR code with their phone camera,
# this controller receives the request, validates the token,
# marks it as used (preventing reuse), and redirects the customer
# to a WhatsApp deep link that opens a pre-populated message
# to the R2R bot — starting the cashback claim conversation.


class QrRedirectsController < ApplicationController
  # GET /r/:token
  # Called when a customer scans the QR code
  def show
    # Look up the QR token record using the token string from the URL
    @qr_token = QrToken.find_by(token: params[:token])

    # Check 1: does this token exist at all?
    if @qr_token.nil?
      render plain: "This QR code is not valid.", status: :not_found
      return
    end

    # Check 2: has this token already been scanned and used?
    if @qr_token.used?
      render plain: "This QR code has already been used. Please ask staff for a new one.", status: :gone
      return
    end

    # Check 3: has this token expired? (tokens expire after 24 hours)
    if @qr_token.expires_at < Time.now
      render plain: "This QR code has expired. Please ask staff for a new one.", status: :gone
      return
    end

    # All checks passed — mark the token as used immediately.
    # This prevents the same QR code being scanned twice (FR9).
    # We update this BEFORE redirecting so even if something goes
    # wrong with the redirect, the token cannot be reused.
    @qr_token.update!(used: true)

    # Build the WhatsApp deep link URL.
    # wa.me expects the phone number with NO plus sign, spaces, or dashes.
    # We strip any stored formatting just in case.
    twilio_config = Rails.application.credentials.twilio
    raw_number = twilio_config.whatsapp_number.to_s
    whatsapp_number = raw_number.gsub(/\D/, "")  # digits only

    message = "R2R-#{@qr_token.token}"
    whatsapp_url = "https://wa.me/#{whatsapp_number}?text=#{CGI.escape(message)}"

    Rails.logger.info "Redirecting to WhatsApp URL: #{whatsapp_url}"

    redirect_to whatsapp_url, allow_other_host: true
  end
end
