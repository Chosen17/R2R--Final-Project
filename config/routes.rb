Rails.application.routes.draw do
  get "transactions/new"
  get "transactions/create"
  resources :transactions, only: [ :new, :create, :show ]
  get "/r/:token", to: "qr_redirects#show"
  root "transactions#new"
end
