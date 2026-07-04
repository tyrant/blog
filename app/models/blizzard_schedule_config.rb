# frozen_string_literal: true

# Singleton holding the saved Blizzard repost forecast: { days, even, shuffle,
# events: [{ c: categorization_id, i: entry_index, t: iso_timestamp }, ...] }.
# The admin calendar renders this on load so the ordering persists across
# reloads and devices; the "Save Forecasts" button overwrites it.
class BlizzardScheduleConfig < ApplicationRecord
  def self.instance
    first_or_create!
  end
end
