# frozen_string_literal: true

# Break-glass admin sign-in for when no passkey works (lost device, all passkeys
# removed). In a production Rails console:
#
#   puts AdminRecovery.url
#
# The link signs that browser in for 15 minutes, long enough to register a new
# passkey at /admin/passkeys. It expires after 15 minutes and stops working as
# soon as any passkey is added or removed, so it can't be replayed after use.
module AdminRecovery
  TTL     = 15.minutes
  PURPOSE = :admin_recovery

  def self.token
    verifier.generate(passkeys_fingerprint, expires_in: TTL, purpose: PURPOSE)
  end

  def self.url
    Rails.application.routes.url_helpers.comfy_admin_recover_url(token: token)
  end

  def self.valid?(token)
    verifier.verified(token.to_s, purpose: PURPOSE) == passkeys_fingerprint
  end

  # Changes whenever a passkey is added or removed.
  def self.passkeys_fingerprint
    AdminPasskey.order(:id).pluck(:id).join(",")
  end

  def self.verifier
    Rails.application.message_verifier(:admin_recovery)
  end
end
