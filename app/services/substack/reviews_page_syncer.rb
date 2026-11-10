# frozen_string_literal: true

# Rebuilds the dedicated "Reviews" Substack pages so they list every featurable
# SubstackQuotation, in stored position order (set by drag-to-reorder in the admin),
# split into pages of SubstackSyncConfig#reviews_page_size reviews. Page 1 is the original page whose id lives
# in SubstackSyncConfig#reviews_draft_id (its "reviews" slug/URL is preserved);
# pages 2..X are auto-created drafts (slug "reviews-page-N") whose ids are appended
# to SubstackSyncConfig#reviews_extra_draft_ids and published with send_email:false.
#
# Each page renders as: a top pagination nav (1 · 2 · … · X, current bold, others
# linked — omitted when there's only one page), page 1's manually-authored intro,
# the review units (native digestPostEmbed card — or a post-title heading fallback
# — then the block-quoted quote and, beneath it, a "🔗 — <thank-you to the
# author>" signature worded like the Blizzard notes), the same nav at the bottom, then the post
# footer template's subscribe CTA ("Bullshit Emeritus: SUBSCRIBE" onward, pulled
# live from SubstackSyncConfig#footer_json — see SUBSCRIBE_CTA_HEADING). Draft
# writes aren't Cloudflare-blocked from the prod IP, so this runs on the prod
# worker. No-op when no page-1 draft id is configured.
#
# `page:` (1-based) rebuilds just that page; nil rebuilds them all. Either way
# every page's draft is read (for the nav's URLs), and each page written is
# stamped with its content fingerprint (SubstackSyncConfig#reviews_page_fingerprints)
# so the admin can flag pages whose quotations have changed since.
module Substack
  class ReviewsPageSyncer
    include ServiceInterface

    arguments client: nil, config: nil, page: nil

    # Marks the post footer's subscribe pitch: an older layout's "Bullshit
    # Emeritus: SUBSCRIBE" heading, or the current layout's audience-specific
    # blocks whose text opens with "Bullshit Emeritus".
    SUBSCRIBE_CTA_HEADING = "Bullshit Emeritus"

    def execute
      @config ||= SubstackSyncConfig.instance
      return if @config.reviews_draft_id.blank?

      @client ||= Substack::Client.new(publication_host: @config.publication_host)

      groups     = @config.reviews_page_groups
      page_count = groups.size
      return if @page && !@page.between?(1, page_count)

      page_ids = ensure_page_ids(page_count)
      drafts   = page_ids.map { |id| @client.get_draft(id) }
      urls     = drafts.each_with_index.map { |draft, i| page_url(draft, i) }
      # The manually-authored intro lives on page 1; extract it once and repeat it
      # on every page.
      page_intro = intro(drafts.first)

      page_ids.each_with_index do |id, i|
        next if @page && i + 1 != @page

        group = groups[i] || []
        body  = page_document(i, page_count, urls, group, page_intro)

        Substack::Client.retrying_subtitle_rejection do
          @client.update_draft(
            id,
            draft_title:       "Sexyverse Advice Reviews Page #{i + 1}",
            draft_subtitle:    SubstackSyncConfig.instance.subtitle_for(nil),
            draft_body:        JSON.generate(body),
            should_send_email: false
          )
        end

        # Stamped after building the page: building can store a quotation's embed
        # snapshot, which bumps its updated_at.
        @config.record_reviews_page_fingerprint!(i + 1, SubstackQuotation.reviews_page_fingerprint(group, page_count))

        # Push edits live: page 1's first publish stays manual (mirroring
        # PostSyncer); auto-created pages 2..X publish on any sync, including
        # their first (send_email:false — no subscriber email is ever sent). When
        # Substack wants a fresh 2FA sign-in, the page is queued for a manual
        # publish and the rebuild carries on with the rest.
        if drafts[i]["is_published"] || i.positive?
          SubstackPendingPublish.publish(@client, id, title: "Reviews page #{i + 1}")
        end
      end

      sync_navigation
      page_ids
    end

    private

    # Bring the publication nav bar in line with the pages. Best-effort: a nav
    # failure (e.g. Cloudflare from the datacenter IP) must never fail the rebuild,
    # which is the important part.
    def sync_navigation
      NavSyncer.execute(client: @client, config: @config)
    rescue => e
      Rails.logger.warn("[ReviewsPageSyncer] nav sync failed: #{e.message}")
    end

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
    # loop once its body is built.
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

      id
    end

    def page_document(index, page_count, urls, reviews, page_intro)
      banner = banner_image(reviews.first)
      nav    = page_count > 1 ? [pagination(index + 1, page_count, urls)] : []
      units  = reviews.flat_map { |quotation| review_unit(quotation) }
      content = banner + nav + page_intro + units + nav + subscribe_cta_blocks
      content = [{ "type" => "paragraph" }] if content.empty?

      {
        "type" => "doc",
        "content" => content
      }
    end

    # The "Bullshit Emeritus: SUBSCRIBE" pitch and everything below it, pulled
    # live from the post footer template (SubstackSyncConfig#footer_json) so
    # Reviews pages stay in step with it automatically rather than duplicating
    # it here.
    #
    # Current layout: the pitch is the audience-specific dynamicContent blocks
    # whose text opens "Bullshit Emeritus", and the footer now ends with the
    # "This post also moonwalks…" platform-links section, which needs a post
    # to resolve — so the CTA stops right before it.
    #
    # Older templates open the pitch with a "Bullshit Emeritus" heading, which
    # TemplateCapturer may have wrapped (heading through to just before the
    # subscribeWidget) in a tag-gated syncIf; the button and what follows are
    # siblings *after* the syncIf and are reattached here. Unwrapped since a
    # Reviews page has no post to check a tag against. [] when the section
    # isn't present yet.
    def subscribe_cta_blocks
      until_links_section(find_cta_blocks(@config.footer_json) || [])
    end

    LINKS_DIRECTIVES = %w[syncPlatformLinks syncOriginalLink].freeze

    # Cut at the platform-links directive, pulled back over the divider and
    # unlinked lead-in headings ("This post also moonwalks…") just above it.
    def until_links_section(blocks)
      stop = blocks.index { |block| LINKS_DIRECTIVES.include?(block["type"]) }
      return blocks unless stop

      stop -= 1 while stop.positive? && links_lead_in?(blocks[stop - 1])
      blocks[0...stop]
    end

    def links_lead_in?(block)
      return true if block["type"] == "horizontal_rule"

      block["type"] == "heading" && !cta_heading?(block) &&
        Array(block["content"]).none? { |node| Array(node["marks"]).any? { |mark| mark["type"] == "link" } }
    end

    def find_cta_blocks(blocks)
      blocks = Array(blocks)
      index = blocks.index { |block| cta_heading?(block) }
      return blocks[index..] if index

      blocks.each_with_index do |block, i|
        next unless block["type"] == "syncIf"

        found = find_cta_blocks(block["content"])
        return found + blocks[(i + 1)..] if found
      end
      nil
    end

    # Where the subscribe pitch starts: an older layout's "Bullshit Emeritus"
    # heading, or the current layout's first audience-specific block whose text
    # opens with it.
    def cta_heading?(block)
      return false unless block.is_a?(Hash)

      case block["type"]
      when "heading"        then block_text(block).include?(SUBSCRIBE_CTA_HEADING)
      when "dynamicContent" then deep_text(block).include?(SUBSCRIBE_CTA_HEADING)
      else false
      end
    end

    def deep_text(node)
      return "" unless node.is_a?(Hash)

      node["text"].to_s + Array(node["content"]).map { |child| deep_text(child) }.join
    end

    def block_text(block)
      Array(block["content"]).flat_map do |n| 
        [n["text"]] + Array(n["content"]).map { |x| x["text"] } 
      end.compact.join
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
      content  = strip_trailing_cta(content)
      boundary = review_start(content)

      boundary ? content[0...boundary] : content
    end

    # Drop the syncer-appended subscribe CTA (its own trailing section) so it's
    # never mistaken for authored intro and carried over — mirrors
    # strip_leading_banner for the same reason, at the other end of the page.
    def strip_trailing_cta(content)
      index = content.index { |block| cta_heading?(block) }

      index ? content[0...index] : content
    end

    # Drop a leading captionedImage — the banner the syncer prepends — so it isn't
    # kept as intro (and duplicated) on the next rebuild.
    def strip_leading_banner(content)
      first = content.first

      first.is_a?(Hash) && first["type"] == "captionedImage" ? content.drop(1) : content
    end

    def review_start(content)
      quote = (0...content.size).find { |i| QuotationBlock.blockquote_em?(content[i]) || QuotationBlock.attribution_paragraph?(content[i]) }
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

    # The Reviews-page quotation unit (post-embed card, block-quoted quote,
    # 🔗 — thank-you signature, spacer), after ensuring the quotation's embed
    # snapshot is populated.
    def review_unit(quotation)
      ensure_embed(quotation)

      QuotationBlock.review_unit(quotation)
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
