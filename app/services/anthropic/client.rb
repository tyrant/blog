# frozen_string_literal: true

require "net/http"
require "json"

# Thin wrapper over the Anthropic Messages API. Stubbed for now: with no API key
# configured, #configured? is false and callers fall back to placeholder output;
# drop a key into credentials (anthropic.api_key) or ENV["ANTHROPIC_API_KEY"] to
# activate real generation.
module Anthropic
  class Client
    BASE          = "https://api.anthropic.com"
    VERSION       = "2023-06-01"
    DEFAULT_MODEL = "claude-sonnet-5"

    class Error < StandardError; end
    class NotConfigured < Error; end

    def self.api_key
      Rails.application.credentials.dig(:anthropic, :api_key) || ENV["ANTHROPIC_API_KEY"]
    end

    def initialize(api_key: self.class.api_key)
      @api_key = api_key
    end

    def configured?
      @api_key.present?
    end

    # Single-turn completion; returns the assistant's plain text.
    def complete(system:, prompt:, model: DEFAULT_MODEL, max_tokens: 1024)
      raise NotConfigured, "No Anthropic API key configured" unless configured?

      req = Net::HTTP::Post.new(URI("#{BASE}/v1/messages"))
      req["x-api-key"]         = @api_key
      req["anthropic-version"] = VERSION
      req["content-type"]      = "application/json"
      req.body = JSON.generate(
        model:      model,
        max_tokens: max_tokens,
        system:     system,
        messages:   [{ role: "user", content: prompt }]
      )

      response = Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: true) { |http| http.request(req) }
      handle(response)
    end

    private

    def handle(response)
      body = JSON.parse(response.body) rescue {}
      return Array(body["content"]).map { |block| block["text"] }.join if response.code.to_i.between?(200, 299)

      raise Error, "Anthropic API #{response.code}: #{body.dig("error", "message") || response.body.to_s[0, 200]}"
    end
  end
end
