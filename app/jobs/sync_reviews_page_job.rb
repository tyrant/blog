# frozen_string_literal: true

# Rebuilds the Reviews Substack page from the whole quotation pool
# (Substack::ReviewsPageSyncer), on the prod worker. Enqueued whenever a
# quotation is added/edited/deleted, and by the manual "Rebuild Reviews page" button.
class SyncReviewsPageJob < ApplicationJob
  queue_as :default

  def perform
    Substack::ReviewsPageSyncer.execute
  end
end
