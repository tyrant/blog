# frozen_string_literal: true

# Builds the attrs for Substack's native "small" post-embed node
# (digestPostEmbed) from a post's public JSON — the denormalised snapshot the
# editor stores (title, cover, trimmed bylines, publication, counts). This mirrors
# exactly the field set Substack's own editor writes, so its render component
# doesn't choke. Returns nil when the post can't be fetched. nodeId is added
# per-node by the caller.
module Substack
  class QuotationEmbed
    include ServiceInterface

    arguments :post_url, client: nil

    BYLINE_KEYS = %w[id name bio photo_url is_guest bestseller_tier].freeze

    def execute
      return nil if @post_url.blank?

      @client ||= Substack::Client.new
      post = @client.get_post(@post_url)
      publication = post.dig("publishedBylines", 0, "publicationUsers", 0, "publication") || {}
      {
        "caption" => nil, "cta" => nil,
        "showBylines" => true, "showDescription" => true, "showImage" => true,
        "size" => "sm", "isEditorNode" => true,
        "title" => post["title"], "publishedBylines" => bylines(post),
        "post_date" => post["post_date"], "cover_image" => post["cover_image"],
        "cover_image_alt" => nil, "canonical_url" => post["canonical_url"],
        "section_name" => nil, "video_upload_id" => nil,
        "id" => post["id"], "type" => "newsletter",
        "reaction_count" => post["reaction_count"], "comment_count" => post["comment_count"],
        "publication_id" => post["publication_id"],
        "publication_name" => post["publication_name"] || publication["name"],
        "publication_logo_url" => post["publication_logo_url"] || publication["logo_url"],
        "belowTheFold" => false, "youtube_url" => nil, "show_links" => nil, "feed_url" => nil
      }
    rescue Substack::Client::Error => e
      Rails.logger.error("[QuotationEmbed] #{@post_url}: #{e.message}")
      nil
    end

    private

    def bylines(post)
      Array(post["publishedBylines"]).map { |byline| byline.slice(*BYLINE_KEYS) }
    end
  end
end
