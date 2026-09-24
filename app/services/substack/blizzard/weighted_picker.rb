# frozen_string_literal: true

# Picks the next entry to suggest reposting, weighted by popularity — always available
# (no due/interval gating; posting is manual, so there's no pace to throttle).
#
# The candidate set + weights come from RepostOdds (postable entries on off-cooldown posts,
# weight = 1 + sum of note likes) — the same source the admin leaderboard shows, so
# the displayed odds match what actually fires. dry_run (what the admin page always
# uses) previews without claiming; a non-dry-run pick stamps last_reposted_at under
# the config row lock, but nothing currently calls it that way.
module Substack
  module Blizzard
    class WeightedPicker
      include ServiceInterface

      arguments dry_run: false, now: nil, random: nil

      # Share of reposts drawn from the SubstackQuotation pool instead of a text
      # group. Falls back down through the tiers below when the pool is empty or
      # every quotation is on cooldown.
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

      # Same cooldown_hours window as RepostOdds/UnattachedOdds, applied per
      # quotation via its own #notes (a quotation repost isn't tracked against a
      # BlizzardScheduleConfig entry, so it can't share their eligible/candidate
      # helpers — see hydrate_quotation below).
      def random_quotation
        cutoff = @now - BlizzardScheduleConfig.instance.cooldown_hours.to_i.hours
        SubstackQuotation.all.reject { |quotation| quotation_on_cooldown?(quotation, cutoff) }.sample(random: @random)
      end

      def quotation_on_cooldown?(quotation, cutoff)
        latest = Array(quotation.notes).filter_map { |note| Time.zone.parse(note["timestamp"].to_s) rescue nil }.max
        latest.present? && latest > cutoff
      end

      # A quotation repost isn't tracked against a Categorization or
      # BlizzardScheduleConfig entry, so categorization_id/uid stay nil — it's
      # tracked against the SubstackQuotation's own #notes instead, via quotation_id.
      def hydrate_quotation(quotation)
        {
          "categorization_id" => nil,
          "uid"               => nil,
          "quotation_id"      => quotation.id,
          "text"              => quotation.quotation,
          "body_json"         => QuotationNote.build(quotation),
          "post_url"          => quotation.post_url,
          "template_url"      => nil
        }
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
      # post_url comes from the entry's own captured preview-card attachment (an
      # unattached note can still reference a post — it's just not ours to track).
      def hydrate_unattached(candidate)
        entry = candidate.entry
        {
          "categorization_id" => nil,
          "uid"               => entry["uid"],
          "text"              => entry["text"],
          "body_json"         => entry["body_json"],
          "post_url"          => entry["post_url"],
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
