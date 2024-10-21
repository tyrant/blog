class User < ApplicationRecord
  has_subscriptions

  validates :email, :name, presence: true
  validates :email, uniqueness: true
end
