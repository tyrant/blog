# frozen_string_literal: true

# Register, list and remove the passkeys that can sign in to /admin.
class Comfy::Admin::PasskeysController < Comfy::Admin::Cms::BaseController
  CHALLENGE_KEY = :admin_passkey_registration_challenge

  def index
    @passkeys = AdminPasskey.order(:created_at)
  end

  def options
    options = WebAuthn::Credential.options_for_create(
      user: { id: AdminPasskey.webauthn_user_id, name: "admin", display_name: "Blog admin" },
      exclude: AdminPasskey.pluck(:external_id),
      authenticator_selection: { resident_key: "required", user_verification: "required" }
    )
    session[CHALLENGE_KEY] = options.challenge
    render json: options
  end

  def create
    challenge  = session.delete(CHALLENGE_KEY)
    credential = WebAuthn::Credential.from_create(params.require(:credential).to_unsafe_h)
    credential.verify(challenge.to_s, user_verification: true)

    passkey = AdminPasskey.create!(
      external_id: credential.id,
      public_key:  credential.public_key,
      sign_count:  credential.sign_count,
      nickname:    params[:nickname].to_s.strip.presence || "Passkey #{AdminPasskey.count + 1}"
    )
    # Registering counts as signing in, so the first passkey (added while still
    # on HTTP Basic) immediately switches you over to the passkey session.
    sign_in_admin!(passkey)
    flash[:success] = "Passkey “#{passkey.nickname}” added."
    render json: { redirect_to: comfy_admin_passkeys_path }
  rescue StandardError => e
    Rails.logger.warn("[admin passkey] registration rejected: #{e.class}: #{e.message}")
    render json: { error: "Couldn't add that passkey: #{e.message}" }, status: :unprocessable_content
  end

  def destroy
    passkey = AdminPasskey.find(params[:id])
    passkey.destroy!
    flash[:success] = "Passkey “#{passkey.nickname}” removed."
    redirect_to comfy_admin_passkeys_path
  end
end
