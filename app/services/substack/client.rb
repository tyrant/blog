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
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30

    def initialize(session_cookie: SubstackSyncConfig.instance.session_cookie,
                   publication_host: SubstackSyncConfig.instance.publication_host)
      @session_cookie = session_cookie
      @publication_host = publication_host
    end

    def get_note(comment_id)
      request(Net::HTTP::Get.new(uri("/api/v1/reader/comment/#{comment_id}")))
    end

    # A cheap authenticated read to verify the session cookie is still valid.
    # Returns true on success; raises AuthError (recorded) if the cookie is dead.
    # Prefers a private draft GET (definitely auth-gated) when a reviews draft is
    # configured, else the logged-in user's subscriptions.
    def verify_session
      draft_id = SubstackSyncConfig.instance.reviews_draft_id
      if draft_id.present? && @publication_host.present?
        request(Net::HTTP::Get.new(pub_uri("/api/v1/drafts/#{draft_id}")))
      else
        request(Net::HTTP::Get.new(uri("/api/v1/subscriptions")))
      end
      true
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

    # Creates a publication nav-bar item. A linkUrl pointing at one of the
    # publication's own posts is resolved server-side to that post (link_url is
    # then cleared and post_id set on the stored item).
    def create_nav_item(link_title:, link_url:)
      req = Net::HTTP::Post.new(pub_uri("/api/v1/publication/navigation-bar-item"))
      req.body = JSON.generate(linkTitle: link_title, linkUrl: link_url)
      request(req)
    end

    # The publication's custom nav items. Substack server-renders these into the
    # homepage's preload JSON rather than exposing a read endpoint, so we fetch the
    # (public) homepage and parse them out. Raises (rather than returning []) when
    # the marker is missing or unparseable — a Cloudflare interstitial returns 200
    # with no marker, and a silent [] would make callers recreate every item.
    def navigation_bar_items
      html = get_html(pub_uri("/"))
      key = html.index("navigationBarItems")
      raise Error, "nav items not found in homepage (blocked or markup changed?)" unless key

      extract_nav_array(html, key)
    end

    def delete_nav_item(id)
      request(Net::HTTP::Delete.new(pub_uri("/api/v1/publication/navigation-bar-item/#{id}")))
    end

    # Reorders the whole custom nav: `ids` is the complete ordered list of nav-item
    # ids (Substack sets each item's siblingRank from its position).
    def reorder_nav_items(ids)
      req = Net::HTTP::Put.new(pub_uri("/api/v1/publication/navigation-bar-item/siblingRank"))
      req.body = JSON.generate(siblingRank: ids)
      request(req)
    end

    private

    def get_html(uri)
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                            open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) { |http| http.request(req) }
      raise Error, "Substack homepage #{res.code}" unless res.code.to_i.between?(200, 299)

      res.body.to_s
    end

    # The navigationBarItems value is an escaped JSON string in the preload; slice
    # out the bracket-balanced array and unescape it.
    def extract_nav_array(html, key)
      start = html.index("[", key)
      raise Error, "nav array start not found" unless start

      depth = 0
      finish = nil
      html[start..].each_char.with_index do |ch, i|
        depth += 1 if ch == "["
        depth -= 1 if ch == "]"
        (finish = start + i) and break if depth.zero?
      end
      raise Error, "nav array not bracket-balanced" unless finish

      JSON.parse(html[start..finish].gsub('\\"', '"').gsub('\\\\') { '\\' })
    rescue JSON::ParserError => e
      raise Error, "nav items unparseable: #{e.message}"
    end

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
        response = Net::HTTP.start(req.uri.host, req.uri.port, use_ssl: true,
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
        record_session_health(recovered: true)
        response.body.present? ? JSON.parse(response.body) : {}
      when 401, 403
        record_session_health(recovered: false, message: "Substack rejected the session cookie (#{response.code})")
        raise AuthError, "Substack rejected the session cookie (#{response.code}) — refresh it"
      else
        raise Error, "Substack API #{response.code}: #{response.body.to_s[0, 300]}"
      end
    end

    # Record the cookie's health on the config singleton so the admin page can
    # surface an expired session. Best-effort: never let health bookkeeping break
    # an actual request.
    def record_session_health(recovered:, message: nil)
      config = SubstackSyncConfig.instance
      recovered ? config.note_session_recovery! : config.note_session_failure!(message)
    rescue => e
      Rails.logger.warn("[Substack] session-health record failed: #{e.message}")
    end
  end
end
