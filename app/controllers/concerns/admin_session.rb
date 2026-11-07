# frozen_string_literal: true

# Who counts as the signed-in admin. Shared by the admin auth gate
# (ComfortableMexicanSofa::AccessControl::AdminAuthentication), the passkey
# sign-in controller, and public pages that show admin-only links.
#
# A passkey sign-in sets a long-lived encrypted cookie naming the passkey used.
# Deleting that passkey (or rotating secret_key_base) revokes the cookie.
module AdminSession
  extend ActiveSupport::Concern

  SESSION_COOKIE = :admin_passkey_session
  SESSION_TTL    = 60.days

  private

  def admin_signed_in?
    admin_dev_bypass? || current_admin_passkey.present?
  end

  # Local dev needs no sign-in: only this machine can reach it. Set
  # ADMIN_AUTH_IN_DEV=1 to try the real passkey flow locally.
  def admin_dev_bypass?
    Rails.env.development? && request.local? && ENV["ADMIN_AUTH_IN_DEV"].blank?
  end

  def current_admin_passkey
    return @current_admin_passkey if defined?(@current_admin_passkey)

    data = cookies.encrypted[SESSION_COOKIE]
    @current_admin_passkey =
      if data.is_a?(Hash) && Time.zone.at(data["at"].to_i) > SESSION_TTL.ago
        AdminPasskey.find_by(id: data["id"])
      end
  end

  def sign_in_admin!(passkey)
    cookies.encrypted[SESSION_COOKIE] = {
      value:     { "id" => passkey.id, "at" => Time.current.to_i },
      expires:   SESSION_TTL,
      httponly:  true,
      secure:    Rails.env.production?,
      same_site: :lax
    }
    @current_admin_passkey = passkey
  end

  def sign_out_admin!
    cookies.delete(SESSION_COOKIE)
    session.delete(:comfy_admin_authenticated)
    @current_admin_passkey = nil
  end
end
