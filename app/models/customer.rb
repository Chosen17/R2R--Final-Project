class Customer < ApplicationRecord
  has_many :transactions          # the customer can have many transactions (entity relationship)
end
