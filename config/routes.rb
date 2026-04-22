Rails.application.routes.draw do
  # Staff-facing receipt processing endpoints
  resources :transactions, only: [ :new, :create, :show ]

  # Customer QR redirect — this is the URL encoded in every QR code.
  # When the customer scans, they land here, the token is validated,
  # and they are redirected to WhatsApp with a pre-populated message.
  get "/r/:token", to: "qr_redirects#show"

  # Twilio WhatsApp webhook — Twilio POSTs every incoming message here.
  # The skip_forgery_protection is handled in the controller itself
  # via a :null_session strategy so CSRF tokens are not required
  # for this external API endpoint.
  post "/webhooks/whatsapp", to: "webhooks#whatsapp"

  # Default root route — staff portal receipt upload form
  root "transactions#new"
end
