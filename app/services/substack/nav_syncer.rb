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

      created = ensure_items(items, page_ids)
      items = @client.navigation_bar_items if created.any? # refetch for the new ids

      prune_stale(items, page_ids)
      reorder(items, page_ids)
      created
    end

    private

    # Create an item for each page that lacks one, and relabel any whose title has
    # drifted (delete + recreate — there's no title-update endpoint). Returns the
    # post ids (re)created. Page 1 keeps the full "Reviews Page 1"; the rest are bare
    # numbers ("2", "3", …) to keep the nav bar compact.
    def ensure_items(items, page_ids)
      by_post = items.each_with_object({}) { |item, memo| pid = item["post_id"]&.to_i; memo[pid] = item if pid }
      page_ids.each_with_index.filter_map do |post_id, index|
        current = by_post[post_id]
        next if current && current["link_title"] == title_for(index)

        @client.delete_nav_item(current["id"]) if current
        @client.create_nav_item(link_title: title_for(index), link_url: page_url(index))
        post_id
      end
    end

    def title_for(index)
      index.zero? ? "Reviews Page 1" : (index + 1).to_s
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
