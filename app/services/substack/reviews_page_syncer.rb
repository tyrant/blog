# frozen_string_literal: true

# Rebuilds the dedicated "Reviews" Substack pages so they list every featurable
# SubstackQuotation, in stored position order (reshuffled by the admin button),
# split into pages of PER_PAGE reviews. Page 1 is the original page whose id lives
# in SubstackSyncConfig#reviews_draft_id (its "reviews" slug/URL is preserved);
# pages 2..X are auto-created drafts (slug "reviews-page-N") whose ids are appended
# to SubstackSyncConfig#reviews_extra_draft_ids and published with send_email:false.
#
# Each page renders as: a top pagination nav (1 · 2 · … · X, current bold, others
# linked — omitted when there's only one page), page 1's manually-authored intro,
# the review units (native digestPostEmbed card — or a post-title heading fallback
# — then the quote + 🔗 + author), and the same nav at the bottom. Draft writes
# aren't Cloudflare-blocked from the prod IP, so this runs on the prod worker.
# No-op when no page-1 draft id is configured.
module Substack
  class ReviewsPageSyncer
    include ServiceInterface

    arguments client: nil, config: nil

    PER_PAGE = 20

    def execute
      @config ||= SubstackSyncConfig.instance
      return if @config.reviews_draft_id.blank?

      @client ||= Substack::Client.new(publication_host: @config.publication_host)
      @created_ids = []

      quotations = SubstackQuotation.featurable.by_position.to_a
      groups     = quotations.each_slice(PER_PAGE).to_a
      page_count = [groups.size, 1].max

      page_ids = ensure_page_ids(page_count)
      drafts   = page_ids.map { |id| @client.get_draft(id) }
      urls     = drafts.each_with_index.map { |draft, i| page_url(draft, i) }
      # The manually-authored intro lives on page 1; extract it once and repeat it
      # on every page.
      page_intro = intro(drafts.first)

      page_ids.each_with_index do |id, i|
        body = page_document(i, page_count, urls, groups[i] || [], page_intro)

        @client.update_draft(
          id,
          draft_title:       "Sexyverse Advice Reviews Page #{i + 1}",
          draft_subtitle:    SubstackSyncConfig.instance.subtitle_for(nil),
          draft_body:        JSON.generate(body),
          should_send_email: false
        )

        # Push edits live once a page is published: page 1's first publish stays
        # manual (mirroring PostSyncer); auto-created pages publish here on their
        # first sync (send_email:false — no subscriber email is ever sent).
        @client.publish_draft(id) if drafts[i]["is_published"] || @created_ids.include?(id)
      end

      page_ids
    end

    private

    # The configured page ids, growing the list by auto-creating any pages the
    # current review count needs beyond what's stored. Never trims on shrink — a
    # now-empty trailing page is just rebuilt empty (and dropped from the nav).
    def ensure_page_ids(page_count)
      ids = @config.reviews_page_ids
      ids << create_page(ids.size) while ids.size < page_count

      ids
    end

    # Create and slug a fresh Reviews page (index is 0-based; page number is
    # index + 1), record its id, and return it. Publishing happens in the main
    # loop once its body is built (tracked via @created_ids).
    def create_page(index)
      bylines = [{ id: @config.author_id, is_guest: false }]
      created = @client.create_draft(
        title: "Reviews Page #{index + 1}",
        subtitle: "",
        body_doc: { "type" => "doc", "content" => [{ "type" => "paragraph" }] },
        bylines: bylines
      )

      id = created.fetch("id")
      @client.update_draft(id, slug: default_slug(index), draft_bylines: bylines)
      @config.add_reviews_page_id!(id)
      @created_ids << id

      id
    end

    def page_document(index, page_count, urls, reviews, page_intro)
      banner = banner_image(reviews.first)
      nav    = page_count > 1 ? [pagination(index + 1, page_count, urls)] : []
      units  = reviews.flat_map { |quotation| review_unit(quotation) }
      content = banner + nav + page_intro + units + nav
      content = [{ "type" => "paragraph" }] if content.empty?

      {
        "type" => "doc",
        "content" => content
      }
    end

    # The page's banner: the cover image of the page's first review's post, at
    # standard width, captioned with that post's title. Empty when there's no
    # first review or it has no stored cover image.
    def banner_image(quotation)
      return [] if quotation.nil? || quotation.post_image_url.blank?

      content = [{ 
        "type" => "image2", 
        "attrs" => banner_attrs(quotation.post_image_url)
      }]
      content << { "type" => "caption", "content" => [QuotationBlock.text(quotation.post_title)] } if quotation.post_title.present?

      [{ 
        "type" => "captionedImage", 
        "content" => content
      }]
    end

    def banner_attrs(src)
      { 
        "src" => src, 
        "alt" => nil, 
        "title" => nil, 
        "height" => nil, 
        "width" => nil,
        "resizeWidth" => 728, 
        "bytes" => nil, 
        "type" => nil, 
        "href" => nil, 
        "imageSize" => "normal" 
      }
    end

    # A centred nav row of page numbers, prefixed "Reviews page: ": the current one
    # bold, the rest linked to their page, separated by " · ".
    def pagination(current, page_count, urls)
      numbers = (1..page_count).flat_map do |n|
        number = n == current ? QuotationBlock.text(n.to_s, marks: [{ "type" => "strong" }]) :
                                 QuotationBlock.text(n.to_s, href: urls[n - 1])
        n == 1 ? [number] : [QuotationBlock.text("  ·  "), number]
      end

      { 
        "type" => "paragraph", 
        "attrs" => { "textAlign" => "center" },
        "content" => [QuotationBlock.text("Reviews page: ")] + numbers
      }
    end

    def page_url(draft, index)
      slug = draft["slug"].presence || default_slug(index)

      "https://#{@config.publication_host}/p/#{slug}"
    end

    def default_slug(index)
      index.zero? ? "reviews" : "reviews-page-#{index + 1}"
    end

    # Everything above the first review on page 1 is manually-authored intro and is
    # kept; the syncer replaces the review run below it. Existing nav rows and the
    # leading banner image (both syncer-owned, re-added on rebuild) are dropped
    # first, then a review is detected by its quote+author pair — the leading title
    # block(s) above that pair (embed card, heading, old cover thumbnail) fold into
    # the review region so they aren't mistaken for intro on the next sync.
    def intro(draft)
      content  = Array(parsed_body(draft)["content"]).reject { |block| nav_block?(block) }
      content  = strip_leading_banner(content)
      boundary = review_start(content)

      boundary ? content[0...boundary] : content
    end

    # Drop a leading captionedImage — the banner the syncer prepends — so it isn't
    # kept as intro (and duplicated) on the next rebuild.
    def strip_leading_banner(content)
      first = content.first

      first.is_a?(Hash) && first["type"] == "captionedImage" ? content.drop(1) : content
    end

    def review_start(content)
      quote = (0...content.size).find { |i| QuotationBlock.blockquote_em?(content[i]) }
      return nil unless quote

      boundary = quote
      boundary -= 1 while boundary.positive? && title_block?(content[boundary - 1])

      boundary
    end

    def title_block?(block)
      block.is_a?(Hash) && %w[heading captionedImage digestPostEmbed].include?(block["type"])
    end

    # A pagination row: a paragraph whose only links all point at a Reviews page.
    def nav_block?(block)
      return false unless block.is_a?(Hash) && block["type"] == "paragraph"

      hrefs = NoteParser.link_hrefs(block)

      hrefs.any? && hrefs.all? { |href| href.to_s.include?("/p/reviews") }
    end

    def parsed_body(draft)
      JSON.parse(draft["draft_body"].to_s)
    rescue JSON::ParserError
      { "content" => [] }
    end

    # The shared quotation unit (post-embed card + quote + author), after ensuring
    # the quotation's embed snapshot is populated.
    def review_unit(quotation)
      ensure_embed(quotation)

      QuotationBlock.unit(quotation)
    end

    # Populate the quotation's digestPostEmbed snapshot the first time it's synced,
    # fetched+cached per post within a run. No-op once stored or when unfetchable.
    def ensure_embed(quotation)
      return if quotation.post_embed.present? || quotation.post_url.blank?

      unless embed_cache.key?(quotation.post_url)
        embed_cache[quotation.post_url] = Substack::QuotationEmbed.execute(post_url: quotation.post_url, client: @client)
      end
      attrs = embed_cache[quotation.post_url]

      quotation.update!(post_embed: attrs) if attrs
    end

    def embed_cache
      @embed_cache ||= {}
    end
  end
end
