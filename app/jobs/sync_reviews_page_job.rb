# frozen_string_literal: true

# Rebuilds the Reviews Substack pages from the quotation pool
# (Substack::ReviewsPageSyncer), on the prod worker — one page (1-based) when
# given, else all of them. Enqueued by each page's "Sync" button in the
# Quotations admin. Runs one at a time, so several clicks queue up rather than
# racing to auto-create the same new page.
class SyncReviewsPageJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(*) { "substack_reviews_pages" }, duration: 15.minutes

  def perform(page = nil)
    Substack::ReviewsPageSyncer.execute(page: page)
  end
end
