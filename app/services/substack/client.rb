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

    MAX_RETRIES = 5
    RETRYABLE   = [429, 502, 503, 504].freeze

    def initialize(session_cookie: SubstackSyncConfig.instance.session_cookie,
                   publication_host: SubstackSyncConfig.instance.publication_host)
      @session_cookie = session_cookie
      @publication_host = publication_host
    end

    def get_note(comment_id)
      request(Net::HTTP::Get.new(uri("/api/v1/reader/comment/#{comment_id}")))
    end

    # A post lives on its publication subdomain, not substack.com — build the API
    # URL from the post URL's host + /p/<slug>.
    def get_post(post_url)
      parsed = URI(post_url.to_s)
      slug = parsed.path[%r{/p/([^/?#]+)}, 1]
      raise Error, "Not a Substack post URL: #{post_url}" if slug.blank? || parsed.host.blank?

      request(Net::HTTP::Get.new(URI("https://#{parsed.host}/api/v1/posts/#{slug}")))
    end

    def create_note(body_json, attachment_ids: [])
      req = Net::HTTP::Post.new(uri("/api/v1/comment/feed"))
      req.body = JSON.generate(
        bodyJson:          body_json,
        tabId:             "for-you",
        replyMinimumRole:  "everyone",
        attachmentIds:     attachment_ids
      )
      request(req)
    end

    # Creates a link attachment (the post preview card) to reference via
    # attachment_ids when creating a note. Returns the attachment's id.
    def create_attachment(url)
      req = Net::HTTP::Post.new(uri("/api/v1/comment/attachment"))
      req.body = JSON.generate(url: url, type: "link")
      request(req)["id"]
    end

    def delete_note(comment_id)
      request(Net::HTTP::Delete.new(uri("/api/v1/comment/#{comment_id}")))
    end

    # Draft (full post) endpoints live on the publication subdomain, authenticated
    # with the same session cookie. Unlike note-creation, draft writes are not
    # Cloudflare-blocked from the server IP, so these can run on the prod worker.
    def create_draft(title:, subtitle:, body_doc:, bylines:, audience: "everyone")
      req = Net::HTTP::Post.new(pub_uri("/api/v1/drafts"))
      req.body = JSON.generate(
        draft_title:    title,
        draft_subtitle: subtitle,
        draft_body:     JSON.generate(body_doc),
        type:           "newsletter",
        audience:       audience,
        draft_bylines:  bylines
      )
      request(req)
    end

    def update_draft(draft_id, attrs)
      req = Net::HTTP::Put.new(pub_uri("/api/v1/drafts/#{draft_id}"))
      req.body = JSON.generate(attrs)
      request(req)
    end

    def get_draft(draft_id)
      request(Net::HTTP::Get.new(pub_uri("/api/v1/drafts/#{draft_id}")))
    end

    def delete_draft(draft_id)
      request(Net::HTTP::Delete.new(pub_uri("/api/v1/drafts/#{draft_id}")))
    end

    # Publishes (or re-publishes) a draft. send_email stays false: the syncer only
    # auto-publishes posts already published once, whose subscriber email was sent
    # at that first publish — so re-publishing edits never re-sends.
    def publish_draft(draft_id, send_email: false)
      req = Net::HTTP::Post.new(pub_uri("/api/v1/drafts/#{draft_id}/publish"))
      req.body = JSON.generate(send_email: send_email)
      request(req)
    end

    # Assigns an existing publication tag (by uuid) to a post/draft. The tag id
    # is a path segment; the body is empty.
    def add_tag(post_id, tag_id)
      request(Net::HTTP::Post.new(pub_uri("/api/v1/post/#{post_id}/tag/#{tag_id}")))
    end

    # Removes a publication tag (by uuid) from a post/draft.
    def remove_tag(post_id, tag_id)
      request(Net::HTTP::Delete.new(pub_uri("/api/v1/post/#{post_id}/tag/#{tag_id}")))
    end

    # Uploads an image (a data: URI) to Substack's CDN; returns the S3 URL to
    # reference from a ProseMirror image node.
    def upload_image(data_uri)
      req = Net::HTTP::Post.new(pub_uri("/api/v1/image"))
      req.body = JSON.generate(image: data_uri)
      request(req)["url"]
    end

    private

    def pub_uri(path)
      raise Error, "No Substack publication host configured" if @publication_host.blank?

      URI("https://#{@publication_host}#{path}")
    end

    def uri(path)
      URI.join(BASE, path)
    end

    def request(req)
      raise AuthError, "No Substack session cookie configured" if @session_cookie.blank?

      req["Cookie"]       = "substack.sid=#{@session_cookie}"
      req["Content-Type"] = "application/json"
      req["Accept"]       = "application/json"
      req["User-Agent"]   = USER_AGENT

      attempt = 0
      loop do
        attempt += 1
        response = Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: true) do |http|
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
        raise AuthError, "Substack rejected the session cookie (#{response.code}) — refresh it"
      else
        raise Error, "Substack API #{response.code}: #{response.body.to_s[0, 300]}"
      end
    end
  end
end
