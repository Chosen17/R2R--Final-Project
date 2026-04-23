# R2R application configuration
# Centralises all business logic constants that might need adjustment
# between deployments (e.g. per restaurant, or between dev and production)
# so they are not scattered throughout the codebase.


module R2rConfig
  # The percentage of the total bill which the customer will receive as cashback.
  # The system allows that percentage to be anywhere between 5%-10%
  # This will be stored as a BigDecimal to ensure precise decimal arithmetic for money values.
  CASHBACK_RATE = BigDecimal("0.10")

  # The minimum that someone needs to have in their cashback balance before they get notifcated to use them
  # notification from WhatsApp will get triggered when hits/exceeds this threshold for the first time.
  REWARD_THRESHOLD = BigDecimal("20.00")



  # WhatsApp Business API has a 24-hour session window for free-form messages after the customer's last message.
  # After 24 hours, only template messages are allowed until the customer interacts again.
  # This constant defines the length of that session window in hours.

  # So inside this window we can send free-form messages (e.g. "Hi John, you have £15.00 cashback ready to use!")
  # but outside the window we need to use pre-approved templates (e.g. "Hi {{1}}, you have {{2}} cashback ready to use!").

  MESSAGING_WINDOW_HOURS = 24
end
