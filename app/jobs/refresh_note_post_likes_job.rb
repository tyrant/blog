# frozen_string_literal: true

# Refreshes the like counts that feed the popularity-weighted reposter: every
# Substack note's ❤ reaction_count (stored per note) and each post's own
# reaction_count (stored on the post), across all Substack categorizations, plus
# the unattached-notes pool (BlizzardScheduleConfig#data). Sequential with gentle
# pacing to stay under Substack's rate limit. Runs daily on the prod worker (reads
# are allowed from the prod IP). Idempotent per LikesRefresher. See
# doc/refresh_note_post_likes_job.md.
class RefreshNotePostLikesJob < ApplicationJob
  include JobProgressReporting

  queue_as :default

  PACING = 1 # second between categorizations

  def perform
    client = Substack::Client.new

    with_progress("refresh_note_post_likes", label: "Refresh note/post likes", total: categorizations.count + 1) do |progress|
      categorizations.find_each do |categorization|
        Substack::Blizzard::LikesRefresher.execute(categorization: categorization, client: client, commit: true)
      rescue => e
        Rails.logger.error("[RefreshNotePostLikesJob] categorization #{categorization.id}: #{e.message}")
      ensure
        progress.advance!
        sleep PACING
      end

      begin
        Substack::Blizzard::LikesRefresher.execute(categorization: BlizzardScheduleConfig.instance, client: client, commit: true)
      rescue => e
        Rails.logger.error("[RefreshNotePostLikesJob] unattached notes: #{e.message}")
      ensure
        progress.advance!
      end
    end
  end

  private

  def categorizations
    Comfy::Cms::Categorization
      .joins(:category)
      .where(comfy_cms_categories: { label: "Substack" })
      .order(:id)
  end
end
