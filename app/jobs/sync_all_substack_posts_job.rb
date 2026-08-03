# frozen_string_literal: true

# Full re-sync of every Substack-linked post by enqueuing a SubstackPostSyncJob
# per post, triggered on demand from the "Re-sync all posts now" button. The
# per-post jobs serialize via SubstackPostSyncJob's limits_concurrency, so they
# never burst against Substack no matter how many are enqueued at once; a failed
# enqueue never aborts the run. Never publishes — PostSyncer only auto-publishes
# posts already live, and no email is re-sent.
class SyncAllSubstackPostsJob < ApplicationJob
  queue_as :default

  def perform
    substack_categorizations.find_each do |categorization|
      SubstackPostSyncJob.perform_later(categorization.categorized_id)
    rescue => e
      Rails.logger.error("[SyncAllSubstackPostsJob] categorization #{categorization.id}: #{e.message}")
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
