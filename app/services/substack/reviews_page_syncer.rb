# frozen_string_literal: true

# Rebuilds the review list on the dedicated "Reviews" Substack page (a standalone
# page/post whose id lives in SubstackSyncConfig#reviews_draft_id) so it lists
# every featurable SubstackQuotation as a QuotationBlock triplet (post-title
# heading → the quote + 🔗 → the author), newest first. Any manually-authored
# intro above the first triplet is preserved; the syncer owns the run of triplets
# below it. Draft writes aren't Cloudflare-blocked from the prod IP, so this runs
# on the prod worker. No-op when no draft id is configured.
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

    # Everything above the first generated quotation triplet is manually-authored
    # intro and is kept; the syncer replaces the triplet run below it.
    def intro(remote)
      content = Array(parsed_body(remote)["content"])
      boundary = (0...content.size).find { |i| QuotationBlock.triplet_at?(content, i) }
      boundary ? content[0...boundary] : content
    end

    def parsed_body(remote)
      JSON.parse(remote["draft_body"].to_s)
    rescue JSON::ParserError
      { "content" => [] }
    end

    def quotation_blocks
      SubstackQuotation.featurable.chronological.flat_map { |quotation| QuotationBlock.build(quotation) }
    end
  end
end
