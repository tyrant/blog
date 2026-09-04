# frozen_string_literal: true

# Picks the next entry to repost, weighted by popularity. Runs server-side (prod
# has the data); the local ticker calls it every couple of minutes and it gates
# itself to one pick per interval_minutes.
#
# The candidate set + weights come from RepostOdds (postable entries on off-cooldown posts,
# weight = 1 + sum of note likes) — the same source the admin leaderboard shows, so
# the displayed odds match what actually fires. On a real pick it stamps
# last_reposted_at under the config row lock (the claim), so overlapping ticks can't
# double-fire. dry_run previews without claiming.
module Substack
  module Blizzard
    class WeightedPicker
      include ServiceInterface

      arguments dry_run: false, now: nil, random: nil

      # Share of reposts drawn from the SubstackQuotation pool instead of a text
      # group. Falls back down through the tiers below when the pool is empty.
      QUOTATION_ODDS = 0.24
      # Share drawn from the unattached-notes pool (BlizzardScheduleConfig#data),
      # on top of QUOTATION_ODDS — so [0, QUOTATION_ODDS) is quotation,
      # [QUOTATION_ODDS, QUOTATION_ODDS + UNATTACHED_ODDS) is unattached, and the
      # remainder is the per-post text pool. Falls back to text when empty.
      UNATTACHED_ODDS = 0.02

      def execute
        @now    ||= Time.current
        @random ||= Random.new

        config = BlizzardScheduleConfig.instance
        config.with_lock do
          next nil unless due?(config)

          roll = @random.rand

          if roll < QUOTATION_ODDS && (quotation = random_quotation)
            config.update!(last_reposted_at: @now) unless @dry_run
            next hydrate_quotation(quotation)
          end

          if roll < QUOTATION_ODDS + UNATTACHED_ODDS && (picked = weighted_sample(UnattachedOdds.execute(now: @now)))
            config.update!(last_reposted_at: @now) unless @dry_run
            next hydrate_unattached(picked)
          end

          picked = weighted_sample(RepostOdds.execute(now: @now))
          next nil if picked.nil?

          config.update!(last_reposted_at: @now) unless @dry_run
          hydrate(picked)
        end
      end

      private

      def random_quotation
        SubstackQuotation.order(Arel.sql("RANDOM()")).first
      end

      # A quotation repost isn't tracked against any entry, so it carries no
      # categorization_id/uid — the ticker posts it and skips the confirm step.
      def hydrate_quotation(quotation)
        {
          "categorization_id" => nil,
          "uid"               => nil,
          "text"              => quotation.quotation,
          "body_json"         => QuotationNote.build(quotation),
          "post_url"          => quotation.post_url,
          "template_url"      => nil
        }
      end

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

      # An unattached-note repost IS tracked, but against BlizzardScheduleConfig's
      # own entries rather than a post's categorization — categorization_id stays
      # nil (there's no post to look up) while uid carries the entry id, which is
      # how RepostRecorder/RepostTicker tell it apart from an untracked quotation.
      def hydrate_unattached(candidate)
        entry = candidate.entry
        {
          "categorization_id" => nil,
          "uid"               => entry["uid"],
          "text"              => entry["text"],
          "body_json"         => entry["body_json"],
          "post_url"          => nil,
          "template_url"      => Array(entry["notes"]).map { |n| n["url"] }.compact.first
        }
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
