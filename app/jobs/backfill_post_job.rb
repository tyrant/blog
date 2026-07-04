# frozen_string_literal: true

# Backfills a single Substack categorization's data["blizzard"] from its notes.
# Substack reads are allowed from the prod IP, so this runs on the prod worker.
# Idempotent (Backfiller skips already-recorded notes), so safe to re-run.
class BackfillPostJob < ApplicationJob
  queue_as :default

  def perform(categorization_id)
    categorization = Comfy::Cms::Categorization.find_by(id: categorization_id)
    return if categorization.nil?

    Substack::Blizzard::Backfiller.execute(categorization: categorization, commit: true)
  end
end
