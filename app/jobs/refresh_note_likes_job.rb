# frozen_string_literal: true

# Refreshes the "likes" count on every Substack note across all categorizations,
# sequentially with gentle pacing to stay under Substack's rate limit. Runs daily
# on the prod worker (reads are allowed from the prod IP). Idempotent per
# LikesRefresher. The recorded likes feed the popularity-weighted reposter.
class RefreshNoteLikesJob < ApplicationJob
  queue_as :default

  PACING = 1 # second between categorizations

  def perform
    client = Substack::Client.new

    categorizations.find_each do |categorization|
      Substack::Blizzard::LikesRefresher.execute(categorization: categorization, client: client, commit: true)
    rescue => e
      Rails.logger.error("[RefreshNoteLikesJob] categorization #{categorization.id}: #{e.message}")
    ensure
      sleep PACING
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
