# frozen_string_literal: true

# Reconciles the Substack publication's nav bar with the Reviews pages: one
# "Reviews Page N" item per page in SubstackSyncConfig#reviews_page_ids, in order.
# Reads the current nav (from the homepage preload) and matches items to pages by
# post_id (a page's draft id is its post id once published), then:
#   - creates an item for any page missing one,
#   - prunes stale Reviews items (ours by title/slug, but no longer a current page),
#   - reorders so the Reviews items follow reviews_page_ids order.
# Only ever touches Reviews items — other custom nav items are left in place (and
# kept ahead of the Reviews block on reorder). Runs after ReviewsPageSyncer.
# Returns the post ids it created an item for.
module Substack
  class NavSyncer
    include ServiceInterface

    arguments client: nil, config: nil

    REVIEWS_TITLE = /\AReviews Page \d+\z/
    REVIEWS_SLUG  = /\Areviews(-page-\d+)?\z/

    def execute
      @config ||= SubstackSyncConfig.instance
      page_ids = @config.reviews_page_ids.map(&:to_i)
      return [] if page_ids.empty?

      @client ||= Substack::Client.new(publication_host: @config.publication_host)
      items = @client.navigation_bar_items

      created = create_missing(items, page_ids)
      items = @client.navigation_bar_items if created.any? # refetch for the new ids

      prune_stale(items, page_ids)
      reorder(items, page_ids)
      created
    end

    private

    def create_missing(items, page_ids)
      present = items.filter_map { |item| item["post_id"]&.to_i }.to_set
      page_ids.each_with_index.filter_map do |post_id, index|
        next if present.include?(post_id)

        @client.create_nav_item(link_title: "Reviews Page #{index + 1}", link_url: page_url(index))
        post_id
      end
    end

    # Delete Reviews items whose post no longer corresponds to a current page (e.g.
    # a removed/recreated page). Conservative: only items we recognise as ours that
    # carry a post_id not in the wanted set — never other custom items.
    def prune_stale(items, page_ids)
      wanted = page_ids.to_set
      stale = items.select { |item| reviews_item?(item) && item["post_id"] && !wanted.include?(item["post_id"].to_i) }
      stale.each { |item| @client.delete_nav_item(item["id"]) }
      items.reject! { |item| stale.include?(item) }
    end

    # Put the Reviews items in reviews_page_ids order; keep any other custom items
    # ahead of them in their existing order. No-op when already in order.
    def reorder(items, page_ids)
      rank = page_ids.each_with_index.to_h
      reviews, others = items.partition { |item| item["post_id"] && rank.key?(item["post_id"].to_i) }
      reviews.sort_by! { |item| rank[item["post_id"].to_i] }
      desired = (others + reviews).map { |item| item["id"] }
      @client.reorder_nav_items(desired) if desired.size > 1 && desired != items.map { |item| item["id"] }
    end

    def reviews_item?(item)
      item["link_title"].to_s.match?(REVIEWS_TITLE) || item.dig("post", "slug").to_s.match?(REVIEWS_SLUG)
    end

    def page_url(index)
      slug = index.zero? ? "reviews" : "reviews-page-#{index + 1}"
      "https://#{@config.publication_host}/p/#{slug}"
    end
  end
end
