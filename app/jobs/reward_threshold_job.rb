# RewardThresholdJob
# Checks if a customer has just crossed the cashback redemption threshold
# and sends them a proactive WhatsApp notification informing them their
# cashback is ready to use. Runs as a background Sidekiq job so the
# webhook controller never waits for this check to complete.
#
# Called after every cashback balance update. Only sends a notification
# the FIRST time the balance crosses the threshold — not every subsequent
# top-up — to avoid spamming the customer repeatedly.
class RewardThresholdJob < ApplicationJob
  queue_as :default

  def perform(customer_id, balance_before, balance_after)
    customer = Customer.find(customer_id)
    threshold = R2rConfig::REWARD_THRESHOLD

    # Only trigger a notification if the balance CROSSED the threshold on
    # this update. If the customer was already above the threshold before,
    # we do not send another notification — they have already been told.
    return unless balance_before < threshold && balance_after >= threshold

    # Construct the notification message with the customer's current
    # balance formatted to two decimal places for display
    message = "Congratulations #{customer.name}! Your cashback balance " \
              "of £#{format('%.2f', balance_after)} is now ready to redeem. " \
              "Show this message to staff on your next visit."

    # Dispatch the outbound message via the existing TwilioMessageJob,
    # which handles 24-hour window checks and Twilio API calls
    TwilioMessageJob.perform_later(customer.phone_number, message)

    Rails.logger.info "Reward threshold notification sent to customer #{customer.id}"
  end
end
