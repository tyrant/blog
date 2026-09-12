# frozen_string_literal: true

# Records a completed quotation repost: appends { url, timestamp, likes: 0 } to the
# SubstackQuotation's own #notes. Idempotent by url. Sibling to RepostRecorder, but a
# quotation's postings live directly on its own column rather than nested inside a
# Categorization/BlizzardScheduleConfig data["blizzard"] entry.
module Substack
  module Blizzard
    class QuotationRecorder
      include ServiceInterface

      arguments :quotation_id, :url, :timestamp

      def execute
        quotation = SubstackQuotation.find_by(id: @quotation_id)
        return if quotation.nil? || @url.blank? || @timestamp.blank?
        return if Array(quotation.notes).any? { |note| note["url"] == @url }

        quotation.update!(notes: Array(quotation.notes) + [{ "url" => @url, "timestamp" => @timestamp, "likes" => 0 }])
      end
    end
  end
end
