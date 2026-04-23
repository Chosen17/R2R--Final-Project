# WebhooksController
# Receives incoming WhatsApp messages forwarded by Twilio.
# Every message from a customer (including the initial QR scan message)
# arrives here as an HTTP POST request. This controller is responsible
# for verifying the request authenticity, identifying or creating the
# customer, processing the message based on the customer's conversation
# state, and enqueueing a reply via Sidekiq.


class WebhooksController < ApplicationController
  # External API endpoints cannot use Rails' CSRF protection because
  # Twilio has no way of obtaining a CSRF token. We disable it here
  # and instead rely on HMAC signature verification for authenticity.
  skip_forgery_protection

  # Before processing anything, verify this request actually came
  # from Twilio by checking the X-Twilio-Signature HTTP header.
  # Without this check, anyone who discovers our webhook URL could
  # send forged messages and award themselves unlimited cashback.
  before_action :verify_twilio_signature

  # POST /webhooks/whatsapp
  # Entry point for every incoming WhatsApp message
  def whatsapp
    # Extract the sender's WhatsApp phone number and the message body
    # from Twilio's webhook payload. Twilio prefixes phone numbers
    # with 'whatsapp:' so we strip that off to get just the E.164 number.
    from = params[:From].to_s.sub("whatsapp:", "")
    message_body = params[:Body].to_s.strip

    Rails.logger.info "Received WhatsApp message from #{from}: #{message_body.inspect}"

    # Find the existing customer by phone number, or initialise a new
    # record if this is their first interaction. Phone number serves
    # as the unique identifier — no separate login or registration.
    customer = Customer.find_or_initialize_by(phone_number: from)

    # If brand new, save with the default conversation state.
    # New customers always start in AWAITING_REGISTRATION until
    # they tell us their name.
    if customer.new_record?
      customer.conversation_state = "AWAITING_REGISTRATION"
      customer.cashback_balance = BigDecimal("0.00")
      customer.save!
    end

    # Update the last_message_at timestamp so the MessagingWindowService
    # can later determine whether we are inside the WhatsApp 24-hour
    # session window (free-form messages) or outside it (template required)
    customer.update!(last_message_at: Time.now)

    # Dispatch the message to the right handler based on the customer's
    # current conversation state. This keeps the controller clean and
    # each state-specific logic isolated in its own private method.
    reply_text = process_message(customer, message_body)

    # Enqueue the reply as a Sidekiq background job so the controller
    # returns 200 OK to Twilio immediately (within the 2-second window).
    # The actual Twilio API call happens asynchronously in the worker.
    TwilioMessageJob.perform_later(from, reply_text)

    # Respond to Twilio with an empty 200 OK — Twilio does not need
    # us to return anything, only acknowledge receipt of the message.
    head :ok
  end

  private

  # Verifies that the incoming request genuinely originated from Twilio
  # by checking the HMAC signature in the X-Twilio-Signature header.
  # Twilio computes this signature using our auth token and the full
  # request URL plus POST parameters. Only someone with our auth token
  # can produce a valid signature — so this acts as authentication.
  def verify_twilio_signature
    # Skip the check in development if we are hitting the endpoint
    # directly from the browser for local testing (no signature header)
    return if Rails.env.development? && request.headers["X-Twilio-Signature"].blank?

    validator = Twilio::Security::RequestValidator.new(
      Rails.application.credentials.twilio.auth_token
    )

    # The URL Twilio signed is the full public URL (ngrok URL in dev).
    # We reconstruct it from the request.
    valid = validator.validate(
      request.original_url,
      request.POST,
      request.headers["X-Twilio-Signature"]
    )

    unless valid
      Rails.logger.warn "Rejected webhook with invalid Twilio signature"
      head :forbidden
    end
  end

  # Routes the incoming message to the correct handler based on the
  # customer's current conversation state in the database.
  # Returns the reply text to send back via WhatsApp.
  def process_message(customer, message_body)
    # The 'balance' keyword works from any state — it is a quick
    # query path that returns the customer's current cashback total
    if message_body.downcase == "balance"
      return "Your current cashback balance is £#{format('%.2f', customer.cashback_balance)}."
    end

    case customer.conversation_state
    when "AWAITING_REGISTRATION"
      handle_registration(customer, message_body)
    when "REGISTERED"
      handle_registered_customer(customer, message_body)
    else
      "Sorry, something went wrong. Please scan a fresh QR code or ask staff for help."
    end
  end

  # Handles the first message from a brand new customer.
  # The expected payload is either the QR token message (R2R-xxxxx)
  # which triggers the registration prompt, or their name in response
  # to being asked for it.
  def handle_registration(customer, message_body)
    # If the message starts with R2R- it's the pre-populated token from
    # scanning the QR code. We look up the associated transaction and
    # remember the pending cashback amount on the customer record.
    if message_body.start_with?("R2R-")
      token = message_body.sub("R2R-", "")
      qr_token = QrToken.find_by(token: token)

      if qr_token.nil?
        return "Sorry, this QR code is not recognised. Please ask staff for a new one."
      end

      # Link the transaction to this customer and remember that a
      # cashback is pending. When they reply with their name we'll
      # then add the amount to their balance.
      transaction = Transaction.find(qr_token.qr_transaction_id)
      transaction.update!(customer_id: customer.id)

      return "Hi! Thanks for visiting. Your cashback of £#{format('%.2f', transaction.cashback_amount)} is ready to add to your account. What's your name?"
    end

    # Otherwise they are replying with their name — save it and
    # upgrade them to REGISTERED state, then add any pending cashback.
    customer.update!(name: message_body, conversation_state: "REGISTERED")

    # Add any pending transactions (where customer_id is set but
    # cashback hasn't been applied) to the customer's balance
    pending_transaction = Transaction.where(customer_id: customer.id, redeemed: false).last
    if pending_transaction
      balance_before = customer.cashback_balance || BigDecimal("0.00")
      customer.increment!(:cashback_balance, pending_transaction.cashback_amount)
      balance_after = customer.cashback_balance
      pending_transaction.update!(redeemed: true)

      # this is where we enqueue a background job being the threshold check
      # to see if the customer cashback balance has been crossed
      # which if so then the notification gets sent out

      RewardThresholdJob.perform_later(customer.id, balance_before, balance_after)

      return "Welcome, #{message_body}! £#{format('%.2f', pending_transaction.cashback_amount)} has been added to your account. Your balance is £#{format('%.2f', customer.cashback_balance)}. Visit us again to earn more!"
    end

    "Welcome, #{message_body}! You're all registered. Scan a receipt QR code next time you visit to earn cashback."
  end

  # Handles messages from existing returning customers.
  # They don't need to re-register — we just add their cashback
  # from the scanned QR and return a confirmation.
  def handle_registered_customer(customer, message_body)
    if message_body.start_with?("R2R-")
      token = message_body.sub("R2R-", "")
      qr_token = QrToken.find_by(token: token)

      if qr_token.nil?
        return "Sorry, this QR code is not recognised. Please ask staff for a new one."
      end

      transaction = Transaction.find(qr_token.qr_transaction_id)
      transaction.update!(customer_id: customer.id)

      # Captures the balance before and after the threshold check
      # so we can pass it to the RewardsThresholdJob to determine if a notification needs to be sent.
      # We use increment! to ensure this is an atomic update in the database, preventing
      balance_before = customer.cashback_balance || BigDecimal("0.00")
      customer.increment!(:cashback_balance, transaction.cashback_amount)
      balance_after = customer.cashback_balance
      transaction.update!(redeemed: true)

      # Enqueue the threshold check job to see if we need to notify the customer that their cashback is ready to redeem.
      # We pass the before and after balances so the job can determine if the threshold was crossed on this update.
      RewardThresholdJob.perform_later(customer.id, balance_before, balance_after)

      return "Welcome back, #{customer.name}! £#{format('%.2f', transaction.cashback_amount)} cashback added. Your new balance is £#{format('%.2f', customer.cashback_balance)}."
    end

    # Fallback for any other message from a registered customer
    "Hi #{customer.name}! Scan a receipt QR code to earn cashback, or reply 'balance' to check your total."
  end
end
