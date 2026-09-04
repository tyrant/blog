# frozen_string_literal: true

# Backfills BlizzardScheduleConfig's own data["blizzard"] (unattached Notes, with
# no parent Post) from its data["notes"] URLs. Substack reads are allowed from the
# prod IP, so this runs on the prod worker. Idempotent (Backfiller skips
# already-recorded notes), so safe to re-run.
class BackfillUnattachedNotesJob < ApplicationJob
  queue_as :default

  def perform
    Substack::Blizzard::Backfiller.execute(categorization: BlizzardScheduleConfig.instance, commit: true)
  end
end
