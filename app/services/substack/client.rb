# frozen_string_literal: true

require "net/http"
require "json"

# Thin wrapper over Substack's internal JSON API, authenticated with the stored
# substack.sid session cookie. Unofficial API: fails loudly on auth errors so a
# stale cookie surfaces immediately rather than silently no-op'ing.
module Substack
  class Client
    BASE = "https://substack.com"
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                 "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

    class Error < StandardError; end
    class AuthError < Error; end

    def initialize(session_cookie: SubstackSyncConfig.instance.session_cookie)
      @session_cookie = session_cookie
    end

    def get_note(comment_id)
      request(Net::HTTP::Get.new(uri("/api/v1/reader/comment/#{comment_id}")))
    end

    def create_note(body_json)
      req = Net::HTTP::Post.new(uri("/api/v1/comment/feed"))
      req.body = JSON.generate(
        bodyJson:          body_json,
        tabId:             "for-you",
        replyMinimumRole:  "everyone"
      )
      request(req)
    end

    def delete_note(comment_id)
      request(Net::HTTP::Delete.new(uri("/api/v1/comment/#{comment_id}")))
    end

    private

    def uri(path)
      URI.join(BASE, path)
    end

    def request(req)
      raise AuthError, "No Substack session cookie configured" if @session_cookie.blank?

      req["Cookie"]       = "substack.sid=#{@session_cookie}"
      req["Content-Type"] = "application/json"
      req["Accept"]       = "application/json"
      req["User-Agent"]   = USER_AGENT

      response = Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: true) do |http|
        http.request(req)
      end

      handle(response)
    end

    def handle(response)
      case response.code.to_i
      when 200..299
        response.body.present? ? JSON.parse(response.body) : {}
      when 401, 403
        raise AuthError, "Substack rejected the session cookie (#{response.code}) — refresh it"
      else
        raise Error, "Substack API #{response.code}: #{response.body.to_s[0, 300]}"
      end
    end
  end
end
