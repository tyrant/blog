# frozen_string_literal: true

# Rebuilds the Substack Favourites suggestions (SubstackEngagement). A full scan
# walks all my posts and Notes; otherwise only content from 60 days before the
# last finished scan onward, since engagement on older pieces has died down.
class ScanSubstackEngagementJob < ApplicationJob
  include JobProgressReporting

  queue_as :default

  PROGRESS_KEY = "scan_substack_engagement"
  OVERLAP = 60.days

  def perform(full: false)
    last_scan = JobProgress.find_by(key: PROGRESS_KEY, status: "finished")&.started_at
    since = full || last_scan.nil? ? nil : last_scan - OVERLAP

    with_progress(PROGRESS_KEY, label: "Scan Substack engagement", total: 0) do |progress|
      Substack::EngagementScanner.execute(since: since, progress: progress)
    end
  end
end
