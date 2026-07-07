# frozen_string_literal: true

# Mix into a job to publish live progress to a JobProgress row (see the admin's
# Background jobs panel). Wrap the work in `with_progress`, calling `advance!` per
# unit; the row is marked finished on success, failed on exception (then re-raised
# so normal job error handling still applies).
module JobProgressReporting
  extend ActiveSupport::Concern

  private

  def with_progress(key, label:, total:)
    progress = JobProgress.begin!(key, label: label, total: total)
    yield progress
    progress.finish!
  rescue
    progress&.finish!(status: "failed")
    raise
  end
end
