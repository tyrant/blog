# frozen_string_literal: true

# Selects the scheduled repost events that are due to be posted now, claims them
# (two-phase: stamps claimed_at under a row lock so a crashed run's claims are
# reclaimed after CLAIM_TIMEOUT), and returns them hydrated with the group's
# body_json/text/post_url for the local poster. Oldest-first, capped at `limit`
# — so a backlog drains gradually across runs rather than posting in one burst.
module Substack
  module Blizzard
    class ScheduleClaimer
      include ServiceInterface

      arguments limit: 5, claim_timeout: 1800, dry_run: false

      def execute
        config = BlizzardScheduleConfig.instance
        config.with_lock do
          schedule   = config.schedule.deep_dup
          now        = Time.current
          cutoff     = now - @claim_timeout.to_i

          candidates = Array(schedule["events"])
            .select { |event| claimable?(event, now, cutoff) }
            .sort_by { |event| event["t"].to_s }

          cats    = categorizations_for(candidates)
          claimed = []
          candidates.each do |event|
            break if claimed.size >= @limit.to_i

            hydrated = hydrate(event, cats)
            next if hydrated.nil?

            event["claimed_at"] = now.utc.iso8601 unless @dry_run
            claimed << hydrated
          end

          config.update!(schedule: schedule) unless @dry_run || claimed.empty?
          claimed
        end
      end

      private

      def claimable?(event, now, cutoff)
        return false unless event["posted_at"].nil?

        due = parse(event["t"])
        return false if due.nil? || due > now

        claimed = parse(event["claimed_at"])
        claimed.nil? || claimed < cutoff
      end

      # Skips events whose group has vanished or has no rich content to post; they
      # stay unclaimed (harmless) rather than looping as un-postable claims.
      def hydrate(event, cats)
        cat = cats[event["c"]]
        return nil if cat.nil?

        entry = Array(cat.data["blizzard"])[event["i"]]
        return nil if entry.nil? || entry["body_json"].blank?

        {
          "categorization_id" => event["c"],
          "index"             => event["i"],
          "t"                 => event["t"],
          "text"              => entry["text"],
          "body_json"         => entry["body_json"],
          "post_url"          => cat.url,
          "template_url"      => Array(entry["notes"]).map { |n| n["url"] }.compact.first
        }
      end

      def categorizations_for(candidates)
        ids = candidates.map { |event| event["c"] }.uniq
        Comfy::Cms::Categorization.where(id: ids).index_by(&:id)
      end

      def parse(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
