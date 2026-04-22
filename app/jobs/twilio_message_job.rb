# TwilioMessageJob
# Sends an outbound WhatsApp message via the Twilio API as a background
# job. Running this asynchronously (rather than directly in the webhook
# controller) ensures the controller can return 200 OK to Twilio within
# the required 2-second webhook response window, preventing Twilio from
# retrying the webhook and duplicating messages.
#
# This class inherits from ApplicationJob which uses ActiveJob with
# Sidekiq as the queue adapter. ActiveJob provides the perform_later
# interface that the webhook controller uses to enqueue jobs.
class TwilioMessageJob < ApplicationJob
  queue_as :default

  # Called by WebhooksController after processing an incoming message.
  # to_number: the customer's WhatsApp phone number (E.164 format)
  # message_body: the text to send back to them
  def perform(to_number, message_body)
    # Read Twilio credentials from Rails encrypted credentials —
    # never from environment variables or hardcoded strings
    twilio_config = Rails.application.credentials.twilio

    # Initialise the Twilio REST client with our Account SID and Auth Token
    client = Twilio::REST::Client.new(
      twilio_config.account_sid,
      twilio_config.auth_token
    )

    # Send the message via Twilio's messages API.
    # Twilio requires WhatsApp numbers to be prefixed with 'whatsapp:'
    # in the from and to fields. Our sandbox number comes from credentials.
    client.messages.create(
      from: "whatsapp:+#{twilio_config.whatsapp_number.to_s.gsub(/\D/, '')}",
      to:   "whatsapp:#{to_number}",
      body: message_body
    )

    Rails.logger.info "Sent WhatsApp reply to #{to_number}"
  rescue Twilio::REST::RestError => e
    # If Twilio returns an error (e.g. sandbox limits, invalid number)
    # log it but do not crash the job — Sidekiq would otherwise retry
    # and could send the same message multiple times
    Rails.logger.error "Twilio error sending message to #{to_number}: #{e.message}"
  end
end
