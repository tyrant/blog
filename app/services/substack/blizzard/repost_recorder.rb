# frozen_string_literal: true

# Records a completed repost (phase two): appends { url, timestamp, likes: 0 } to
# the entry's notes, found by uid. Idempotent — a repeated confirm of the same URL
# won't double-append. The fresh note starts at zero likes; the daily refresher
# fills in its real count later.
module Substack
  module Blizzard
    class RepostRecorder
      include ServiceInterface

      arguments :categorization_id, :uid, :url, :timestamp

      def execute
        cat = Comfy::Cms::Categorization.find_by(id: @categorization_id)
        return if cat.nil?

        entry = Array(cat.data["blizzard"]).find { |e| e["uid"] == @uid }
        return if entry.nil? || @url.blank? || @timestamp.blank?
        return if Array(entry["notes"]).any? { |note| note["url"] == @url }

        entry["notes"] << { "url" => @url, "timestamp" => @timestamp, "likes" => 0 }
        cat.data_will_change! # in-place jsonb mutation can dodge dirty-tracking
        cat.save!
      end
    end
  end
end
