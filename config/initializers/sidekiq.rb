# Sidekiq configuration for background job processing.
# Sidekiq is used for asynchronous tasks like sending WhatsApp messages,
# so the webhook controller can respond to Twilio within 2 seconds and
# prevent webhook retry storms.

require "sidekiq"

# Configure the Redis connection URL used by Sidekiq.
# In development, Redis is expected to be running locally on default port 6379.
# In production this would be overridden via the REDIS_URL environment variable.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

# Apply Redis URL to the Sidekiq server (the process that runs jobs)
Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

# Apply Redis URL to the Sidekiq client (the Rails app that enqueues jobs)
Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
