# frozen_string_literal: true

# Passkey (WebAuthn) sign-in for /admin. The relying party is the site itself,
# taken from ROOT_URL: passkeys registered on prod (https://mikeyclarke.co.nz)
# only work there, and dev ones (http://localhost:3000) only work locally.
root_url = URI.parse(ENV.fetch("ROOT_URL", "http://localhost:3000"))

WebAuthn.configure do |config|
  config.allowed_origins = [root_url.origin]
  config.rp_id           = root_url.host
  config.rp_name         = "Blog admin"
  config.encoding        = :base64url
end
