# frozen_string_literal: true

# Records an hourly snapshot of the Substack Blizzard totals (posts / entries /
# notes) for the "Totals over time" graph. Pure DB counts — no external API — so
# it runs cheaply on the prod worker.
class RecordBlizzardStatsJob < ApplicationJob
  queue_as :default

  def perform
    BlizzardStatSnapshot.record!
  end
end
