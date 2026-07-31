# frozen_string_literal: true

require "net/http"
require "json"

# Thin wrapper over the AT Protocol XRPC API, authenticated with an app password
# (revocable, not the account password). Sessions are short-lived: the app
# password is exchanged for an accessJwt on the first write and reused for the
# rest of the run. Fails loudly on auth errors like the Substack client, so a
# revoked password surfaces immediately rather than silently no-op'ing.
module Bluesky
  class Client
    class Error < StandardError; end
    class AuthError < Error; end

    MAX_RETRIES = 5
    RETRYABLE   = [429, 502, 503, 504].freeze
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30

    def initialize(handle: BlueskySyncConfig.instance.handle,
                   app_password: BlueskySyncConfig.instance.app_password,
                   host: BlueskySyncConfig.instance.service_host.presence || "https://bsky.social")
      @handle = handle
      @app_password = app_password
      @host = host
    end

    # Creates an app.bsky.feed.post record; returns { "uri" => "at://…", "cid" => … }.
    def create_post(record)
      post_json("com.atproto.repo.createRecord",
        { repo: did, collection: "app.bsky.feed.post", record: record },
        bearer: session.fetch("accessJwt"))
    end

    # Uploads raw image bytes (Bluesky caps blobs at 1,000,000 bytes); returns the
    # blob reference to embed as a link-card thumbnail.
    def upload_blob(bytes, content_type)
      req = Net::HTTP::Post.new(xrpc_uri("com.atproto.repo.uploadBlob"))
      req["Content-Type"] = content_type
      req["Authorization"] = "Bearer #{session.fetch("accessJwt")}"
      req.body = bytes
      request(req).fetch("blob")
    end

    private

    def did
      session.fetch("did")
    end

    def session
      @session ||= authenticate
    end

    # com.atproto.server.createSession — unauthenticated; exchanges the app
    # password for an accessJwt + did.
    def authenticate
      raise AuthError, "No Bluesky credentials configured" if @handle.blank? || @app_password.blank?

      post_json("com.atproto.server.createSession",
        { identifier: @handle, password: @app_password })
    end

    def post_json(method, body, bearer: nil)
      req = Net::HTTP::Post.new(xrpc_uri(method))
      req["Content-Type"] = "application/json"
      req["Authorization"] = "Bearer #{bearer}" if bearer
      req.body = JSON.generate(body)
      request(req)
    end

    def xrpc_uri(method)
      URI("#{@host}/xrpc/#{method}")
    end

    def request(req)
      req["Accept"] = "application/json"

      attempt = 0
      loop do
        attempt += 1
        response = Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: req.uri.scheme == "https",
                                   open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(req)
        end

        if RETRYABLE.include?(response.code.to_i) && attempt <= MAX_RETRIES
          backoff_sleep(retry_after(response, attempt))
          next
        end

        return handle(response)
      end
    end

    def retry_after(response, attempt)
      [response["Retry-After"].to_i, 10 * attempt].max
    end

    def backoff_sleep(seconds)
      sleep(seconds)
    end

    def handle(response)
      case response.code.to_i
      when 200..299
        response.body.present? ? JSON.parse(response.body) : {}
      when 401, 403
        raise AuthError, "Bluesky rejected the app password (#{response.code})"
      else
        raise Error, "Bluesky XRPC #{response.code}: #{response.body.to_s[0, 300]}"
      end
    end
  end
end
