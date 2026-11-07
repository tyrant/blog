# frozen_string_literal: true

# A WebAuthn passkey that can sign in to /admin. There is one admin, so passkeys
# aren't tied to a user row: every passkey here grants admin access.
#
# Lockout recovery (Rails console): `AdminPasskey.destroy_all` — with no
# passkeys left, the old HTTP Basic credentials work again so you can register
# a new one.
class AdminPasskey < ApplicationRecord
  validates :external_id, presence: true, uniqueness: true
  validates :public_key, :nickname, presence: true

  # The WebAuthn user handle shared by every admin passkey (base64url). It's
  # derived from secret_key_base, so it's stable per environment with nothing
  # to store, and authenticators group all admin passkeys under one account.
  def self.webauthn_user_id
    key = Rails.application.key_generator.generate_key("admin-passkey-user-handle", 32)
    Base64.urlsafe_encode64(key, padding: false)
  end
end
