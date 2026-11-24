# frozen_string_literal: true

# Rotates the mirror-managed featured-quote block on every Substack-linked post:
# fetches each draft, swaps in a fresh random SubstackQuotation, and saves the
# draft. Never publishes: already-published posts are flagged "needs
# publishing" for a manual Update. Sequential with gentle pacing to stay under Substack's rate limit.
# Fires daily via config/recurring.yml but self-gates on the configured
# rotation interval (SubstackSyncConfig#quotation_rotation_days).
class RotateSubstackQuotationsJob < ApplicationJob
  queue_as :default

  PACING = 0.5 # seconds between posts

  def perform
    config = SubstackSyncConfig.instance
    return unless config.quotation_rotation_enabled?
    return unless config.quotation_rotation_due?
    return if SubstackQuotation.none?

    client = Substack::Client.new
    processed = 0
    errored = 0
    substack_categorizations.find_each do |categorization|
      rotate(categorization, client)
      processed += 1
    rescue => e
      errored += 1
      Rails.logger.error("[RotateSubstackQuotationsJob] categorization #{categorization.id}: #{e.message}")
    ensure
      sleep PACING
    end

    # Advance the rotation clock unless every attempt errored (e.g. a dead session
    # cookie). Stamping it on a fully-failed run would self-gate retries for the
    # whole rotation interval, silently freezing quotations.
    config.update!(quotations_rotated_at: Time.current) unless processed.zero? && errored.positive?
  end

  private

  def substack_categorizations
    Comfy::Cms::Categorization
      .joins(:category)
      .where(comfy_cms_categories: { label: "Substack" })
      .where.not(data: {})
      .order(:id)
  end

  def rotate(categorization, client)
    substack_id = categorization.data["id"]
    return if substack_id.blank?

    remote = client.get_draft(substack_id)
    body = parse_body(remote["draft_body"])
    return unless body

    fresh = SubstackQuotation.sample_excluding(categorization.url, 10)
    rotated = Substack::QuotationBlock.rotate(body["content"], fresh)
    return if rotated == body["content"] # no quotation region in this draft

    body["content"] = rotated
    client.update_draft(substack_id, draft_body: JSON.generate(body))
    # Never published automatically — the rotation waits in the draft until Updated by hand.
    SubstackPendingPublish.record!(substack_id, remote["draft_title"]) if remote["is_published"]
  end

  def parse_body(raw)
    doc = JSON.parse(raw.to_s)
    doc if doc.is_a?(Hash) && doc["content"].is_a?(Array)
  rescue JSON::ParserError
    nil
  end
end
