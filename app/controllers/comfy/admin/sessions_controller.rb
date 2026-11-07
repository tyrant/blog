# frozen_string_literal: true

# Passkey sign-in for /admin. Deliberately outside Comfy::Admin::BaseController
# so it isn't behind the admin auth gate itself.
class Comfy::Admin::SessionsController < ActionController::Base
  include AdminSession

  CHALLENGE_KEY = :admin_passkey_sign_in_challenge

  protect_from_forgery with: :exception
  rate_limit to: 30, within: 5.minutes, only: %i[options create recover]

  layout "admin_sign_in"

  def new
    redirect_to consume_return_to if admin_signed_in?
  end

  # Discoverable-credential request: no allow-list, so the browser offers every
  # passkey it has for this site and no username is needed.
  def options
    options = WebAuthn::Credential.options_for_get(user_verification: "required")
    session[CHALLENGE_KEY] = options.challenge
    render json: options
  end

  def create
    challenge  = session.delete(CHALLENGE_KEY)
    credential = WebAuthn::Credential.from_get(params.require(:credential).to_unsafe_h)
    passkey    = AdminPasskey.find_by(external_id: credential.id)
    raise WebAuthn::Error, "unknown passkey #{credential.id}" if passkey.nil?

    credential.verify(challenge.to_s, public_key: passkey.public_key, sign_count: passkey.sign_count,
                                      user_verification: true)
    passkey.update!(sign_count: credential.sign_count, last_used_at: Time.current)
    sign_in_admin!(passkey)
    render json: { redirect_to: consume_return_to }
  rescue StandardError => e
    Rails.logger.warn("[admin passkey] sign-in rejected: #{e.class}: #{e.message}")
    render json: { error: "That passkey wasn't accepted." }, status: :unprocessable_content
  end

  # Console-issued break-glass link (see AdminRecovery).
  def recover
    if AdminRecovery.valid?(params[:token])
      start_admin_recovery!
      flash[:warning] = "Recovery sign-in: it lasts #{AdminRecovery::TTL.inspect}. Add a passkey now."
      redirect_to comfy_admin_passkeys_path
    else
      flash[:danger] = "That recovery link is invalid, expired, or already used."
      redirect_to comfy_admin_sign_in_path
    end
  end

  def destroy
    sign_out_admin!
    redirect_to comfy_admin_sign_in_path, notice: "Signed out."
  end

  private

  # Where to go after signing in: the admin page that bounced you here, if it's
  # a same-site path; otherwise the admin root.
  def consume_return_to
    path = session.delete(:admin_return_to).to_s
    path.match?(%r{\A/(?![/\\])}) ? path : "/admin"
  end
end
