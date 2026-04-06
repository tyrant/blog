# frozen_string_literal: true

# Derive default_url_options from the ROOT_URL environment variable so that
# url_helpers (e.g. root_url) and Action Mailer both generate correct absolute
# URLs in every environment.
if ENV["ROOT_URL"].present?
  uri = URI.parse(ENV["ROOT_URL"])
  url_opts = { host: uri.host, protocol: uri.scheme }
  url_opts[:port] = uri.port unless [80, 443].include?(uri.port)

  Rails.application.routes.default_url_options = url_opts
  Rails.application.config.action_mailer.default_url_options = url_opts
end
