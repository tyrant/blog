# frozen_string_literal: true

# Finds blizzard text-groups whose most recent repost is older than max_age_days,
# across every Substack categorization. Drives the admin "due" list and any cron
# reposting.
module Substack
  module Blizzard
    class DueFinder
      include ServiceInterface

      arguments max_age_days: 14, title_query: nil

      Due = Struct.new(:categorization, :index, :entry, :latest, keyword_init: true)

      def execute
        cutoff = @max_age_days.to_i.days.ago

        due = categorizations.flat_map do |categorization|
          Array(categorization.data["blizzard"]).each_with_index.filter_map do |entry, index|
            latest = latest_timestamp(entry)
            next unless latest.nil? || latest < cutoff

            Due.new(categorization: categorization, index: index, entry: entry, latest: latest)
          end
        end

        # Most stale first: never-posted (nil) before the oldest most-recent note.
        due.sort_by { |d| d.latest || Time.zone.at(0) }
      end

      private

      def categorizations
        scope = Comfy::Cms::Categorization
          .joins(:category)
          .where(comfy_cms_categories: { label: "Substack" })
          .includes(:categorized)
          .order(:id)
        return scope if @title_query.blank?

        q = @title_query.downcase
        scope.select { |c| c.categorized.try(:title).to_s.downcase.include?(q) }
      end

      def latest_timestamp(entry)
        Array(entry["notes"])
          .filter_map { |n| Time.zone.parse(n["timestamp"].to_s) rescue nil }
          .max
      end
    end
  end
end
