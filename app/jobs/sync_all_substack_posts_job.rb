# frozen_string_literal: true

# Full re-sync of every Substack-linked post via SubstackPostSyncJob (run inline
# so the single-post sync path is the one entry point), triggered on demand from
# the "Re-sync all posts now" button. Sequential with gentle pacing to stay under
# Substack's rate limit; one failing post never aborts the run. Never publishes —
# PostSyncer only auto-publishes posts already live, and no email is re-sent.
class SyncAllSubstackPostsJob < ApplicationJob
  queue_as :default

  PACING = 1 # seconds between posts

  def perform
    substack_categorizations.find_each do |categorization|
      SubstackPostSyncJob.perform_now(categorization.categorized_id)
    rescue => e
      Rails.logger.error("[SyncAllSubstackPostsJob] categorization #{categorization.id}: #{e.message}")
    ensure
      sleep PACING
    end
  end

  private

  def substack_categorizations
    Comfy::Cms::Categorization
      .joins(:category)
      .where(comfy_cms_categories: { label: "Substack" })
      .where.not(data: {})
      .order(:id)
  end
end
