# frozen_string_literal: true

# Rebuilds the review list on the dedicated "Reviews" Substack page (a standalone
# page/post whose id lives in SubstackSyncConfig#reviews_draft_id) so it lists
# every featurable SubstackQuotation, newest first: each review is a native
# "small" post-embed card (digestPostEmbed, when we have the post id) — or the
# plain post-title heading as a fallback — followed by the quote + 🔗 and the
# author. Any manually-authored intro above the first review is preserved; the
# syncer owns the run below it. Draft writes aren't Cloudflare-blocked from the
# prod IP, so this runs on the prod worker. No-op when no draft id is configured.
module Substack
  class ReviewsPageSyncer
    include ServiceInterface

    arguments client: nil, config: nil

    def execute
      @config ||= SubstackSyncConfig.instance
      draft_id = @config.reviews_draft_id
      return if draft_id.blank?

      @client ||= Substack::Client.new(publication_host: @config.publication_host)
      remote = @client.get_draft(draft_id)
      @client.update_draft(draft_id,
        draft_title:       remote["draft_title"],
        draft_subtitle:    remote["draft_subtitle"],
        draft_body:        JSON.generate(document(remote)),
        should_send_email: false)
      # Push edits live only once it's been published at least once (first publish
      # stays a manual step, mirroring PostSyncer).
      @client.publish_draft(draft_id) if remote["is_published"]
      draft_id
    end

    private

    def document(remote)
      content = intro(remote) + quotation_blocks
      content = [{ "type" => "paragraph" }] if content.empty?
      { "type" => "doc", "content" => content }
    end

    # Everything above the first review is manually-authored intro and is kept;
    # the syncer replaces the review run below it. A review is detected by its
    # quote+author pair (em-blockquote then right-aligned author); the leading
    # title block(s) above that pair — the embed card, heading, and/or an old
    # cover-image thumbnail — are folded into the review region so they aren't
    # mistaken for intro on the next sync.
    def intro(remote)
      content = Array(parsed_body(remote)["content"])
      boundary = review_start(content)
      boundary ? content[0...boundary] : content
    end

    def review_start(content)
      pair = (0...content.size).find do |i|
        QuotationBlock.blockquote_em?(content[i]) && QuotationBlock.author_right?(content[i + 1])
      end
      return nil unless pair

      boundary = pair
      boundary -= 1 while boundary.positive? && title_block?(content[boundary - 1])
      boundary
    end

    def title_block?(block)
      block.is_a?(Hash) && %w[heading captionedImage digestPostEmbed].include?(block["type"])
    end

    def parsed_body(remote)
      JSON.parse(remote["draft_body"].to_s)
    rescue JSON::ParserError
      { "content" => [] }
    end

    def quotation_blocks
      SubstackQuotation.featurable.chronological.flat_map { |quotation| review_unit(quotation) }
    end

    # The post-embed card (or the plain post-title heading fallback) followed by
    # the quote and author from the shared QuotationBlock triplet.
    def review_unit(quotation)
      _heading, blockquote, attribution = QuotationBlock.build(quotation)
      lead = quotation.post_id.present? ? embed_card(quotation) : _heading
      [lead, blockquote, attribution]
    end

    # Substack's native "small" post-embed (digestPostEmbed). We supply the id +
    # canonical_url + title + cover; Substack rehydrates bylines/counts from the id
    # at render. nodeId is unique per node.
    def embed_card(quotation)
      { "type" => "digestPostEmbed", "attrs" => {
        "nodeId" => SecureRandom.uuid, "caption" => nil, "cta" => nil,
        "showBylines" => true, "showDescription" => true, "showImage" => true,
        "size" => "sm", "isEditorNode" => true, "type" => "newsletter",
        "id" => quotation.post_id, "canonical_url" => quotation.post_url,
        "title" => quotation.post_title, "cover_image" => quotation.post_image_url
      } }
    end
  end
end
