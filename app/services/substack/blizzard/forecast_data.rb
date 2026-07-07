# frozen_string_literal: true

# Assembles the client-side forecast payload: every blizzard text-group across
# all Substack categorizations, each with its most-recent note timestamp (the
# recurrence anchor). The admin calendar plots anchor + n×days occurrences in
# the browser, so the interval and horizon deliberately live client-side, not here.
module Substack
  module Blizzard
    class ForecastData
      include ServiceInterface
      include Rails.application.routes.url_helpers

      arguments

      def execute
        categorizations.flat_map do |categorization|
          post = categorization.categorized
          Array(categorization.data["blizzard"]).map do |entry|
            {
              categorizationId: categorization.id,
              uid:              entry["uid"],
              anchor:  latest_timestamp(entry)&.iso8601,
              title:   post&.title.presence || "(untitled post)",
              content: entry["text"].to_s,
              url:     categorization.url,
              editUrl: post && edit_comfy_admin_blog_post_path(site_id: post.site_id, id: post.id)
            }
          end
        end
      end

      private

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
