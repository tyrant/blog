# frozen_string_literal: true

# One hourly snapshot of the Substack Blizzard totals. `current_totals` is the
# single source of truth for the counts — the admin's live Totals panel and each
# recorded snapshot both read it, so they can't drift.
class BlizzardStatSnapshot < ApplicationRecord
  scope :chronological, -> { order(:captured_at) }

  def self.current_totals
    data = Comfy::Cms::Categorization
      .joins(:category)
      .where(comfy_cms_categories: { label: "Substack" })
      .pluck(:data)

    {
      posts:   Comfy::Blog::Post.count,
      entries: data.sum { |d| Array(d&.dig("blizzard")).size },
      notes:   data.sum { |d| Array(d&.dig("blizzard")).sum { |entry| Array(entry["notes"]).size } }
    }
  end

  def self.record!
    create!(current_totals.merge(captured_at: Time.current))
  end
end
