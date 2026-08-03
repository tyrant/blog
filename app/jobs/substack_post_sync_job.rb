# frozen_string_literal: true

# Mirrors one Comfy post to its Substack draft on the prod worker. Enqueued from
# the post editor's "Sync to Substack" button and by SyncAllSubstackPostsJob.
class SubstackPostSyncJob < ApplicationJob
  queue_as :default

  # Serialize every Substack sync (bulk re-sync, per-post button, cron) through a
  # single shared key, so however many are enqueued they run one at a time and
  # never burst against Substack's rate limits. duration is the safety expiry that
  # releases the slot if a job is lost — far longer than a sync actually takes.
  limits_concurrency to: 1, key: "substack", duration: 5.minutes

  def perform(post_id)
    Substack::PostSyncer.execute(post_id: post_id)
  end
end
