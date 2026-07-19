# frozen_string_literal: true

# Rebuilds the dedicated "Reviews" Substack page (a standalone page/post whose id
# lives in SubstackSyncConfig#reviews_draft_id) so its body lists every featurable
# SubstackQuotation as a QuotationBlock triplet (post-title heading → the quote +
# 🔗 → the author), newest first. Draft writes aren't Cloudflare-blocked from the
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
        draft_body:        JSON.generate(document),
        should_send_email: false)
      # Push edits live only once it's been published at least once (first publish
      # stays a manual step, mirroring PostSyncer).
      @client.publish_draft(draft_id) if remote["is_published"]
      draft_id
    end

    private

    def document
      blocks = SubstackQuotation.featurable.chronological.flat_map { |quotation| QuotationBlock.build(quotation) }
      blocks = [{ "type" => "paragraph" }] if blocks.empty?
      { "type" => "doc", "content" => blocks }
    end
  end
end
