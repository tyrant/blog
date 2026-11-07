# frozen_string_literal: true

# Shared secret the local Blizzard rake tasks (substack:blizzard:tick,
# preview_quotation) send as a Bearer token to prod's Blizzard JSON endpoints,
# in place of an admin browser session. Set `blizzard: { api_token: … }` in the
# production credentials and the same value locally (development credentials or
# BLIZZARD_API_TOKEN).
module BlizzardApiToken
  def self.value
    ENV["BLIZZARD_API_TOKEN"].presence || Rails.application.credentials.dig(:blizzard, :api_token).to_s
  end

  def self.valid?(provided)
    expected = value
    expected.present? && provided.present? &&
      ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected)
  end
end
