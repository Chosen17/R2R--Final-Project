# MessagingWindowService
# Determines whether a customer is currently within WhatsApp's 24-hour
# customer service window, which dictates what type of message can be sent.
#
# WhatsApp Business API policy:
#   - INSIDE the 24-hour window: free-form messages are permitted
#   - OUTSIDE the 24-hour window: only pre-approved template messages
#
# This service provides a single source of truth for the check, used by
# the TwilioMessageJob before every outbound send. For the prototype we
# log when we would be outside the window but still send free-form, since
# the Twilio sandbox does not enforce the 24-hour rule. In production with
# a live WhatsApp Business number, this service would switch to sending a
# pre-approved template message instead.


Class MessagingWindowService
  def initialize(customer)
  @customer = customer
  end



# Returns true if customers has sent a message within the 24 window which
# is the configured window and if otherwise return false

def inside_window?
  return false if @customer.last_message_at.nil?

  @customer.last_message_at > R2rConfig::MESSAGING_WINDOW_HOURS.hours.ago
end


# check for outisde the window and log it for visibility, but still return false to allow free-form messages in the prototype.
# In production, we would use this check to decide whether to send a template message instead.
def outside_window?
  !inside_window?
end
