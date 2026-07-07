# frozen_string_literal: true

# Live progress for a long-running background job — one row per job type, keyed and
# upserted so each run overwrites the last. Written by the worker (via
# JobProgressReporting), polled by the admin's Background jobs panel.
class JobProgress < ApplicationRecord
  STATUSES = %w[running finished failed].freeze

  # Start (or restart) tracking a run: resets counts and marks it running.
  def self.begin!(key, label:, total:)
    record = find_or_initialize_by(key: key)
    record.update!(label: label, total: total, completed: 0, status: "running", detail: nil, started_at: Time.current)
    record
  end

  def advance!(detail: nil)
    update!(completed: completed + 1, detail: detail)
  end

  def finish!(status: "finished")
    update!(status: status)
  end

  def percent
    total.to_i.positive? ? (100.0 * completed / total).round : 0
  end

  def running?
    status == "running"
  end
end
