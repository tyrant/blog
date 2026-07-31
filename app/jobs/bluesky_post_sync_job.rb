# frozen_string_literal: true

# Mirrors one Comfy post to Bluesky as a teaser. Enqueued from the post editor's
# "Sync to Bluesky" button.
class BlueskyPostSyncJob < ApplicationJob
  queue_as :default

  def perform(post_id)
    Bluesky::PostSyncer.execute(post_id: post_id)
  end
end
