# frozen_string_literal: true

# Backfills every Substack categorization's data["blizzard"] from its notes,
# sequentially with gentle pacing to stay under Substack's rate limit. Runs on
# the prod worker (reads are allowed from the prod IP). Idempotent per Backfiller.
class BackfillAllJob < ApplicationJob
  include JobProgressReporting

  queue_as :default

  PACING = 1 # second between categorizations

  def perform
    client = Substack::Client.new

    with_progress("backfill_all", label: "Backfill all posts’ notes", total: categorizations.count) do |progress|
      categorizations.find_each do |categorization|
        Substack::Blizzard::Backfiller.execute(categorization: categorization, client: client, commit: true)
      rescue => e
        Rails.logger.error("[BackfillAllJob] categorization #{categorization.id}: #{e.message}")
      ensure
        progress.advance!
        sleep PACING
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
