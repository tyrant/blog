# frozen_string_literal: true

# The current repost lottery: every eligible entry (postable body_json, past its
# cooldown) with its selection weight (1 + the sum of its notes' likes) and the
# resulting probability of being the next repost. Shared by WeightedPicker (which
# samples from it) and the admin "most likely to repost" leaderboard, so the
# displayed odds always match real behaviour.
module Substack
  module Blizzard
    class RepostOdds
      include ServiceInterface

      arguments now: nil

      BASE_WEIGHT = 1

      Candidate = Struct.new(:categorization, :entry, :weight, :probability, keyword_init: true) do
        def title
          categorization.categorized&.title.presence || "(untitled post)"
        end

        def text
          entry["text"].to_s
        end

        def likes
          weight - BASE_WEIGHT
        end
      end

      # Natural order (categorization id, then entry order) — WeightedPicker samples
      # over this, so the order is kept stable; the leaderboard re-sorts by weight.
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
        categorizations.flat_map do |categorization|
          post_likes = categorization.categorized.try(:substack_likes).to_i
          Array(categorization.data["blizzard"]).filter_map do |entry|
            next if entry["body_json"].blank?

            latest = latest_timestamp(entry)
            next if latest && latest > cutoff

            Candidate.new(categorization: categorization, entry: entry, weight: weight(entry, post_likes))
          end
        end
      end

      # 1 (base) + the entry's own note likes + the post's likes (shared by all its
      # entries), so a popular post lifts every one of its entries.
      def weight(entry, post_likes)
        BASE_WEIGHT + note_likes(entry) + post_likes
      end

      def note_likes(entry)
        Array(entry["notes"]).sum { |note| note["likes"].to_i }
      end

      def categorizations
        Comfy::Cms::Categorization
          .joins(:category)
          .where(comfy_cms_categories: { label: "Substack" })
          .includes(:categorized)
          .order(:id)
      end

      def latest_timestamp(entry)
        Array(entry["notes"])
          .filter_map { |n| Time.zone.parse(n["timestamp"].to_s) rescue nil }
          .max
      end
    end
  end
end
