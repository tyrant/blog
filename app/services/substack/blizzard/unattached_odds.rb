# frozen_string_literal: true

# The unattached-notes lottery: candidates from BlizzardScheduleConfig's own
# data["blizzard"] (Notes with no parent Post or Quotation), weighted the same
# way as RepostOdds (1 + the sum of the entry's notes' likes) — there's no
# parent post, so no post-likes term, and cooldown rests each entry
# individually (there's no post to bench as a group).
module Substack
  module Blizzard
    class UnattachedOdds
      include ServiceInterface

      arguments now: nil

      BASE_WEIGHT = 1

      Candidate = Struct.new(:entry, :weight, :probability, keyword_init: true) do
        def text
          entry["text"].to_s
        end

        def uid
          entry["uid"]
        end

        def likes
          weight - BASE_WEIGHT
        end
      end

      def execute
        @now ||= Time.current
        cutoff = @now - BlizzardScheduleConfig.instance.cooldown_hours.to_i.hours

        candidates = eligible(cutoff)
        total = candidates.sum(&:weight)
        candidates.each { |c| c.probability = total.positive? ? c.weight.to_f / total : 0.0 }
        candidates
      end

      private

      def eligible(cutoff)
        entries.filter_map do |entry|
          next if entry["body_json"].blank?
          next if on_cooldown?(entry, cutoff)

          Candidate.new(entry: entry, weight: weight(entry))
        end
      end

      def on_cooldown?(entry, cutoff)
        latest = latest_timestamp(entry)
        latest.present? && latest > cutoff
      end

      def weight(entry)
        BASE_WEIGHT + note_likes(entry)
      end

      def note_likes(entry)
        Array(entry["notes"]).sum { |note| note["likes"].to_i }
      end

      def entries
        Array(BlizzardScheduleConfig.instance.data["blizzard"])
      end

      def latest_timestamp(entry)
        Array(entry["notes"])
          .filter_map { |n| Time.zone.parse(n["timestamp"].to_s) rescue nil }
          .max
      end
    end
  end
end
