# frozen_string_literal: true

class Email < ApplicationRecord

  validates :address, 
    presence: { message: "Oh come on, write something" },
    uniqueness: { message: "We've already got this one" }
  validate :truemail_valid, if: -> (r) { r.address.present? }

  def notification_type
    if valid?
      'success'
    else
      'error'
    end
  end

  def notification_content
    if valid?
      'Welcome aboard!'
    else
      errors.messages.values.join(', ')
    end
  end

  private

  def truemail_valid
    errors.add(:address, "You reckon that's an email address?") unless Truemail.valid?(address)
  end
end
