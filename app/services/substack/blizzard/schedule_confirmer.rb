# frozen_string_literal: true

# Records a completed scheduled post (phase two): appends {url, timestamp} to the
# group's notes and marks the schedule event posted, under a row lock. Idempotent
# — a repeated confirm won't double-append the note or re-mark the event. Appends
# the note even if the event has since vanished (e.g. a re-save), so the real post
# is never lost.
module Substack
  module Blizzard
    class ScheduleConfirmer
      include ServiceInterface

      arguments :categorization_id, :uid, :t, :url, :timestamp

      def execute
        config = BlizzardScheduleConfig.instance
        config.with_lock do
          append_note
          mark_posted(config)
        end
      end

      private

      def append_note
        cat = Comfy::Cms::Categorization.find_by(id: @categorization_id)
        return if cat.nil?

        entry = Array(cat.data["blizzard"]).find { |e| e["uid"] == @uid }
        return if entry.nil? || @url.blank? || @timestamp.blank?
        return if Array(entry["notes"]).any? { |note| note["url"] == @url }

        entry["notes"] << { "url" => @url, "timestamp" => @timestamp }
        cat.data_will_change! # in-place jsonb mutation can dodge dirty-tracking
        cat.save!
      end

      def mark_posted(config)
        schedule = config.schedule.deep_dup
        event = Array(schedule["events"]).find do |e|
          e["c"] == @categorization_id.to_i && e["u"] == @uid && e["t"] == @t
        end
        return if event.nil? || event["posted_at"].present?

        event["posted_at"] = Time.current.utc.iso8601
        event.delete("claimed_at")
        config.update!(schedule: schedule)
      end
    end
  end
end
