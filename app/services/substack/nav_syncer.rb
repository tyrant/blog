# frozen_string_literal: true

# Reconciles the Substack publication's nav bar with the Reviews pages, in
# SubstackSyncConfig#reviews_page_ids order. Up to SHOW_ALL_MAX pages get an item
# each; beyond that only the first and last EDGE_COUNT do, with ellipses bridging
# the gap: "Reviews Page 1", "2", "3...", "...18", "19", "20".
# Reads the current nav (from the homepage preload) and matches items to pages by
# post_id (a page's draft id is its post id once published), then:
#   - creates an item for any page missing one,
#   - prunes stale Reviews items (no longer a current page, or a page now elided),
#   - reorders so the Reviews items follow reviews_page_ids order.
# Only ever touches Reviews items — other custom nav items are left in place (and
# kept ahead of the Reviews block on reorder). Runs after ReviewsPageSyncer.
# Returns the post ids it created an item for.
module Substack
  class NavSyncer
    include ServiceInterface

    arguments client: nil, config: nil

    REVIEWS_TITLE = /\AReviews Page \d+\z/
    EDGE_COUNT    = 3
    SHOW_ALL_MAX  = EDGE_COUNT * 2
    REVIEWS_SLUG  = /\Areviews(-page-\d+)?\z/

    def execute
      @config ||= SubstackSyncConfig.instance
      page_ids = @config.reviews_page_ids.map(&:to_i)
      return [] if page_ids.empty?

      @client ||= Substack::Client.new(publication_host: @config.publication_host)
      items = @client.navigation_bar_items

      shown = shown_indexes(page_ids.size)
      created = ensure_items(items, page_ids, shown)
      items = @client.navigation_bar_items if created.any? # refetch for the new ids

      prune_stale(items, page_ids, shown)
      reorder(items, page_ids.values_at(*shown))
      created
    end

    private

    # Indexes of the pages that get a nav item: all of them when few, else the
    # first and last EDGE_COUNT.
    def shown_indexes(count)
      return (0...count).to_a if count <= SHOW_ALL_MAX

      (0...EDGE_COUNT).to_a + ((count - EDGE_COUNT)...count).to_a
    end

    # Create an item for each page that lacks one, and relabel any whose title has
    # drifted (delete + recreate — there's no title-update endpoint). Returns the
    # post ids (re)created. Page 1 keeps the full "Reviews Page 1"; the rest are bare
    # numbers ("2", "3", …) to keep the nav bar compact.
    def ensure_items(items, page_ids, shown)
      by_post = items.each_with_object({}) { |item, memo| pid = item["post_id"]&.to_i; memo[pid] = item if pid }
      shown.filter_map do |index|
        post_id = page_ids[index]
        title = title_for(index, page_ids.size)
        current = by_post[post_id]
        next if current && current["link_title"] == title

        @client.delete_nav_item(current["id"]) if current
        @client.create_nav_item(link_title: title, link_url: page_url(index))
        post_id
      end
    end

    # When pages are elided, the items either side of the gap carry the ellipsis.
    def title_for(index, count)
      return "Reviews Page 1" if index.zero?

      number = (index + 1).to_s
      return number if count <= SHOW_ALL_MAX

      case index
      when EDGE_COUNT - 1     then "#{number}..."
      when count - EDGE_COUNT then "...#{number}"
      else number
      end
    end

    # Delete Reviews items not in the shown set: a removed/recreated page, or a page
    # now elided from the middle. Conservative: only items we recognise as ours (by
    # title/slug, or pointing at a current page) — never other custom items.
    def prune_stale(items, page_ids, shown)
      wanted = page_ids.values_at(*shown).to_set
      pages = page_ids.to_set
      stale = items.select do |item|
        pid = item["post_id"]&.to_i
        pid && !wanted.include?(pid) && (pages.include?(pid) || reviews_item?(item))
      end
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
