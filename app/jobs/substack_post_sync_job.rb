# frozen_string_literal: true

# Mirrors one Comfy post to its Substack draft on the prod worker. Enqueued from
# the post editor's "Sync to Substack" button.
class SubstackPostSyncJob < ApplicationJob
  queue_as :default

  def perform(post_id)
    Substack::PostSyncer.execute(post_id: post_id)
  end
end
