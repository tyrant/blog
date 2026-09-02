# frozen_string_literal: true

module Substack
  # Builds and detects the featured-quote blocks. When the quotation has a
  # post_embed snapshot, it renders as a three-block unit: a native "small"
  # post-embed card (its caption *is* the quote, but Substack's mobile CSS
  # hides that caption — kept only for the rich preview), a blockquote of the
  # quote (marked em, always visible) with the attribution nested below it as
  # a second paragraph, then a centred h5 "." spacer beneath the pair. Without
  # a snapshot it falls back to the older three-block shape: an h4 heading
  # linking the post, a blockquote of the italicised quote (with the same
  # inline attribution), and a centred "." spacer. The template's
  # syncQuotations directive expands into N of these; the rotation job finds
  # the run in a draft (of any shape) and swaps them for fresh ones.
  module QuotationBlock
    module_function

    def unit(quotation)
      lead = card(quotation)
      return [lead, quote_blockquote(quotation), trailing_spacer] if lead

      [heading(quotation), blockquote(quotation), spacer]
    end

    # The heading-only unit (no embed card) — kept for the heading fallback and
    # for callers/tests that want the plain triplet.
    def build(quotation)
      [heading(quotation), blockquote(quotation), spacer]
    end

    # Substack's native "small" post-embed, from the stored snapshot, captioned
    # with the quote itself; nil when the quotation has no snapshot (falls back
    # to the heading). nodeId is per-node.
    def card(quotation)
      return nil if quotation.post_embed.blank?

      attrs = quotation.post_embed.merge(
        "nodeId" => SecureRandom.uuid, "size" => "sm", "caption" => "“#{quotation.quotation}”"
      )
      { "type" => "digestPostEmbed", "attrs" => attrs }
    end

    # A centred h5 "." spacer beneath a card unit — matches the reference
    # draft's own spacing between one preview+quote pair and the next.
    def trailing_spacer
      { "type" => "heading", "attrs" => { "textAlign" => "center", "level" => 5 }, "content" => [text(".")] }
    end

    # The card unit's quote + attribution, both always visible regardless of
    # Substack's per-device embed styling: the quote (marked em) as the
    # blockquote's first paragraph, the attribution (🔗, em-dash, linked
    # commenter) nested below it as a second paragraph.
    def quote_blockquote(quotation)
      attribution_nodes = []
      attribution_nodes << text("🔗", href: quotation.comment_url) if quotation.comment_url.present?
      attribution_nodes << text(" — ")
      attribution_nodes << text(quotation.author_name, href: quotation.author_url)

      { "type" => "blockquote", "content" => [
        { "type" => "paragraph", "attrs" => { "textAlign" => "left" },
          "content" => [text("“#{quotation.quotation}”", marks: [{ "type" => "em" }])] },
        { "type" => "paragraph", "attrs" => { "textAlign" => "left" }, "content" => attribution_nodes }
      ] }
    end

    def heading(quotation)
      { "type" => "heading", "attrs" => { "textAlign" => nil, "level" => 4 },
        "content" => [text(quotation.post_title, href: quotation.post_url)] }
    end

    def blockquote(quotation)
      nodes = [text("“#{quotation.quotation}”", marks: [{ "type" => "em" }])]
      if quotation.comment_url.present?
        nodes << text(" ")
        nodes << text("🔗", href: quotation.comment_url)
      end
      nodes << text(" — ")
      nodes << text(quotation.author_name, href: quotation.author_url)
      { "type" => "blockquote", "content" => [
        { "type" => "paragraph", "attrs" => { "textAlign" => "left" }, "content" => nodes }
      ] }
    end

    # A centred "." separator paragraph after each quote.
    def spacer
      { "type" => "paragraph", "attrs" => { "textAlign" => "center" }, "content" => [text(".")] }
    end

    # Replace the contiguous run of quotation units in an existing draft body
    # with fresh ones (same count), in place. Units may be either shape (see
    # module docs) and a run may mix both, e.g. mid-migration. Returns the
    # content unchanged when no run is found.
    def rotate(content, quotations)
      start = (0...content.size).find { |i| triplet_at?(content, i) }
      return content unless start

      count, stop = walk_units(content, start)
      fresh = quotations.first(count).flat_map { |quotation| unit(quotation) }
      content[0...start] + fresh + content[stop..]
    end

    # Walks a contiguous run of quotation units starting at index, returning
    # [unit count, index just past the run].
    def walk_units(content, index)
      count = 0
      offset = index
      while (length = unit_length_at(content, offset))
        count += 1
        offset += length
      end
      [count, offset]
    end

    # A quotation unit at index: any shape (see module docs). Returns the
    # block length of the unit found there (2 or 3), or nil if none matches.
    def unit_length_at(content, index)
      return 3 if card_with_trailing_spacer?(content, index)
      return 2 if quotation_lead?(content[index]) && attribution_paragraph?(content[index + 1])
      return 3 if quotation_lead?(content[index]) && blockquote_em?(content[index + 1]) && paragraph?(content[index + 2])

      nil
    end

    # The current card shape: a post-embed card, a blockquote carrying both
    # the quote and (nested as a second paragraph) its attribution, then a
    # centred "." heading spacer.
    def card_with_trailing_spacer?(content, index)
      post_embed_card?(content[index]) &&
        attributed_blockquote?(content[index + 1]) &&
        period_heading?(content[index + 2])
    end

    def period_heading?(block)
      return false unless block.is_a?(Hash) && block["type"] == "heading"

      Array(block["content"]).any? { |node| node["text"].to_s.strip == "." }
    end

    # A blockquote whose first paragraph is the em-marked quote and whose
    # second paragraph is the attribution (carries a link mark).
    def attributed_blockquote?(block)
      return false unless blockquote_em?(block)

      attribution_para = Array(block["content"])[1]
      Array(attribution_para&.dig("content")).any? { |node| Array(node["marks"]).any? { |mark| mark["type"] == "link" } }
    end

    def triplet_at?(content, index)
      !unit_length_at(content, index).nil?
    end

    # The card unit's marker block: a right-aligned paragraph carrying a 🔗
    # link, i.e. an `attribution` output.
    def attribution_paragraph?(block)
      return false unless block.is_a?(Hash) && block["type"] == "paragraph" && block.dig("attrs", "textAlign") == "right"

      Array(block["content"]).any? { |node| node["text"] == "🔗" && Array(node["marks"]).any? { |mark| mark["type"] == "link" } }
    end

    def quotation_lead?(block)
      heading_post_link?(block) || post_embed_card?(block)
    end

    def post_embed_card?(block)
      block.is_a?(Hash) && block["type"] == "digestPostEmbed"
    end

    def paragraph?(block)
      block.is_a?(Hash) && block["type"] == "paragraph"
    end

    def heading_post_link?(block)
      block.is_a?(Hash) && block["type"] == "heading" && link_href(block).to_s.include?("/p/")
    end

    def blockquote_em?(block)
      return false unless block.is_a?(Hash) && block["type"] == "blockquote"

      para = Array(block["content"]).first
      Array(para&.dig("content")).any? { |node| Array(node["marks"]).any? { |mark| mark["type"] == "em" } }
    end

    def text(string, href: nil, marks: [])
      marks = marks.dup
      marks << link(href) if href.present?
      node = { "type" => "text", "text" => string.to_s }
      node["marks"] = marks if marks.any?
      node
    end

    def link(href)
      { "type" => "link", "attrs" => { "href" => href, "target" => "_blank",
                                       "rel" => "noopener noreferrer nofollow", "class" => nil } }
    end

    def link_href(block)
      Array(block["content"]).each do |node|
        Array(node["marks"]).each { |mark| return mark.dig("attrs", "href") if mark["type"] == "link" }
      end
      nil
    end
  end
end
