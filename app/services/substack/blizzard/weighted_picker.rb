# frozen_string_literal: true

# Picks the next entry to repost, weighted by popularity. Runs server-side (prod
# has the data); the local ticker calls it every couple of minutes and it gates
# itself to one pick per interval_minutes.
#
# An entry's weight is BASE + the sum of its notes' likes, so heavily-liked
# entries are reposted more often, while never-posted / zero-like entries keep a
# small (BASE) chance. Entries reposted within cooldown_hours, and entries with no
# postable body_json, are excluded.
#
# On a real pick it stamps last_reposted_at under the config row lock (the claim),
# so overlapping ticks can't double-fire. dry_run previews without claiming.
module Substack
  module Blizzard
    class WeightedPicker
      include ServiceInterface

      arguments dry_run: false, now: nil, random: nil

      BASE_WEIGHT = 1

      def execute
        @now    ||= Time.current
        @random ||= Random.new

        config = BlizzardScheduleConfig.instance
        config.with_lock do
          next nil unless due?(config)

          picked = weighted_sample(eligible_entries(config))
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

      # [{ categorization:, entry:, weight: }] for every postable, off-cooldown entry.
      def eligible_entries(config)
        cutoff = @now - config.cooldown_hours.to_i.hours
        entries = []

        categorizations.each do |categorization|
          Array(categorization.data["blizzard"]).each do |entry|
            next if entry["body_json"].blank?

            latest = latest_timestamp(entry)
            next if latest && latest > cutoff

            entries << { categorization: categorization, entry: entry, weight: weight(entry) }
          end
        end
        entries
      end

      def weight(entry)
        BASE_WEIGHT + Array(entry["notes"]).sum { |note| note["likes"].to_i }
      end

      def weighted_sample(candidates)
        total = candidates.sum { |c| c[:weight] }
        return nil if total <= 0

        threshold = @random.rand(total)
        candidates.each do |candidate|
          threshold -= candidate[:weight]
          return candidate if threshold < 0
        end
        candidates.last
      end

      def hydrate(picked)
        entry = picked[:entry]
        {
          "categorization_id" => picked[:categorization].id,
          "uid"               => entry["uid"],
          "text"              => entry["text"],
          "body_json"         => entry["body_json"],
          "post_url"          => picked[:categorization].url,
          "template_url"      => Array(entry["notes"]).map { |n| n["url"] }.compact.first
        }
      end

      def categorizations
        Comfy::Cms::Categorization
          .joins(:category)
          .where(comfy_cms_categories: { label: "Substack" })
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
