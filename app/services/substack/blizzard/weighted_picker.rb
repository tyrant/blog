# frozen_string_literal: true

# Picks the next entry to repost, weighted by popularity. Runs server-side (prod
# has the data); the local ticker calls it every couple of minutes and it gates
# itself to one pick per interval_minutes.
#
# The candidate set + weights come from RepostOdds (postable, off-cooldown entries,
# weight = 1 + sum of note likes) — the same source the admin leaderboard shows, so
# the displayed odds match what actually fires. On a real pick it stamps
# last_reposted_at under the config row lock (the claim), so overlapping ticks can't
# double-fire. dry_run previews without claiming.
module Substack
  module Blizzard
    class WeightedPicker
      include ServiceInterface

      arguments dry_run: false, now: nil, random: nil

      def execute
        @now    ||= Time.current
        @random ||= Random.new

        config = BlizzardScheduleConfig.instance
        config.with_lock do
          next nil unless due?(config)

          picked = weighted_sample(RepostOdds.execute(now: @now))
          next nil if picked.nil?

          config.update!(last_reposted_at: @now) unless @dry_run
          hydrate(picked)
        end
      end

      private

      def due?(config)
        last = config.last_reposted_at
        last.nil? || last <= @now - config.interval_minutes.to_i.minutes
      end

      def weighted_sample(candidates)
        total = candidates.sum(&:weight)
        return nil if total <= 0

        threshold = @random.rand(total)
        candidates.each do |candidate|
          threshold -= candidate.weight
          return candidate if threshold < 0
        end
        candidates.last
      end

      def hydrate(candidate)
        entry = candidate.entry
        {
          "categorization_id" => candidate.categorization.id,
          "uid"               => entry["uid"],
          "text"              => entry["text"],
          "body_json"         => entry["body_json"],
          "post_url"          => candidate.categorization.url,
          "template_url"      => Array(entry["notes"]).map { |n| n["url"] }.compact.first
        }
      end
    end
  end
end
