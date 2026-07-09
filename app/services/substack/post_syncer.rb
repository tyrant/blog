# frozen_string_literal: true

require "net/http"
require "base64"

# Mirrors a Comfy blog post into a Substack draft (never publishes — publishing
# is the only email-triggering step and stays a separate, deliberate action).
# Idempotent: the first sync creates a draft and stores its id on the post;
# later syncs PUT that same draft. Draft writes are not Cloudflare-blocked from
# the server IP, so this runs on the prod worker.
module Substack
  class PostSyncer
    include ServiceInterface

    arguments :post_id, client: nil, config: nil

    def execute
      # Draw the blog routes if a bare context (e.g. a job before a web request)
      # left them unloaded, so ComfyBlog.config.public_blog_path — and thus
      # post.url's "/blog" prefix — is populated. No-op once routes are loaded.
      Rails.application.routes_reloader.execute_unless_loaded

      post = Comfy::Blog::Post.find(@post_id)
      @config ||= SubstackSyncConfig.instance
      @client ||= Substack::Client.new(publication_host: @config.publication_host)

      doc = HtmlToProseMirror.execute(html: post.content_cache.to_s, image_resolver: method(:resolve_image))
      # Drop any Original link the post baked into its own body (often a stale
      # slug); the mirror owns that block, canonically rebuilt from post.url.
      doc["content"].reject! { |block| original_link_block?(block) }
      doc["content"].concat([original_link_heading(post.url)], Array(@config.footer_json))
      subtitle = @config.subtitle.to_s
      bylines  = [{ id: @config.author_id, is_guest: false }]

      if (target_id = target_post_id(post))
        @client.update_draft(target_id,
          draft_title: post.title.to_s, draft_subtitle: subtitle,
          draft_body: JSON.generate(doc), draft_bylines: bylines)
        post.update_column(:substack_draft_id, target_id) unless post.substack_draft_id == target_id
        target_id
      else
        created = @client.create_draft(title: post.title.to_s, subtitle: subtitle, body_doc: doc, bylines: bylines)
        post.update_column(:substack_draft_id, created["id"])
        created["id"]
      end
    end

    private

    # Where edits go. An existing published Substack post (linked via the
    # post's Substack categorization URL) takes precedence, so we edit it in
    # place rather than spawn a parallel draft. Otherwise a draft we previously
    # created (substack_draft_id), else nil — meaning create a fresh draft.
    def target_post_id(post)
      url = post.socials_url_for(platform: "substack").presence
      return post.substack_draft_id if url.blank?

      @client.get_post(url).fetch("id")
    end

    # A block is a stray Original link if it's a paragraph/heading whose text
    # starts with "Original:" and carries a link mark.
    def original_link_block?(block)
      return false unless %w[paragraph heading].include?(block["type"])

      texts = []
      linked = false
      walk = lambda do |node|
        return unless node.is_a?(Hash)

        if node["type"] == "text"
          texts << node["text"].to_s
          linked ||= Array(node["marks"]).any? { |m| m["type"] == "link" }
        end
        Array(node["content"]).each { |child| walk.call(child) }
      end
      walk.call(block)

      linked && texts.join.strip.match?(/\AOriginal:/i)
    end

    # The "Original: <link>" h5 linking back to the canonical blog post, matching
    # the block Substack posts carry by hand. post.url is protocol-relative.
    def original_link_heading(post_url)
      url = post_url.to_s.sub(%r{\A//}, "https://")
      {
        "type"  => "heading",
        "attrs" => { "textAlign" => "left", "level" => 5 },
        "content" => [
          { "type" => "text", "text" => "Original: " },
          { "type" => "text", "text" => url, "marks" => [{
            "type" => "link",
            "attrs" => { "href" => url, "target" => "_blank", "rel" => "noopener noreferrer nofollow", "class" => nil }
          }] }
        ]
      }
    end

    def resolve_image(src)
      data = download_image(src)
      return nil unless data

      @client.upload_image("data:#{data[:content_type]};base64,#{Base64.strict_encode64(data[:body])}")
    rescue => e
      Rails.logger.warn("[SubstackSync] image upload failed for #{src}: #{e.message}")
      nil
    end

    # Reads local ActiveStorage blobs straight from storage (avoiding an HTTP
    # round-trip back into the same process); falls back to a plain GET otherwise.
    def download_image(url)
      if (match = url.match(%r{/rails/active_storage/blobs/(?:redirect|inline)/([^/]+)/}))
        blob = ActiveStorage::Blob.find_signed!(match[1])
        return { body: blob.download, content_type: blob.content_type || "image/jpeg" }
      end

      uri = URI(url)
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                            open_timeout: 10, read_timeout: 30) { |http| http.get(uri.request_uri) }
      return nil unless res.is_a?(Net::HTTPSuccess)

      { body: res.body, content_type: res["content-type"]&.split(";")&.first&.strip || "image/jpeg" }
    rescue => e
      Rails.logger.warn("[SubstackSync] image download failed for #{url}: #{e.message}")
      nil
    end
  end
end
