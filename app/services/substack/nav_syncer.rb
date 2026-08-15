# frozen_string_literal: true

# Keeps the Substack publication's nav bar in step with the Reviews pages: ensures
# one "Reviews Page N" nav item per page in SubstackSyncConfig#reviews_page_ids.
# Additive and idempotent — reads the current nav (from the homepage preload),
# matches items to pages by post_id (a page's draft id is its post id once
# published), and creates only the missing ones. It never reorders or touches
# non-Reviews nav items, and doesn't prune (removing an item needs a delete
# endpoint that isn't wired yet). Returns the post ids it created an item for.
module Substack
  class NavSyncer
    include ServiceInterface

    arguments client: nil, config: nil

    def execute
      @config ||= SubstackSyncConfig.instance
      page_ids = @config.reviews_page_ids
      return [] if page_ids.empty?

      @client ||= Substack::Client.new(publication_host: @config.publication_host)
      existing = existing_post_ids

      page_ids.each_with_index.filter_map do |post_id, index|
        next if existing.include?(post_id.to_i)

        @client.create_nav_item(link_title: "Reviews Page #{index + 1}", link_url: page_url(index))
        post_id
      end
    end

    private

    def existing_post_ids
      @client.navigation_bar_items.filter_map { |item| item["post_id"]&.to_i }
    end

    def page_url(index)
      slug = index.zero? ? "reviews" : "reviews-page-#{index + 1}"
      "https://#{@config.publication_host}/p/#{slug}"
    end
  end
end
