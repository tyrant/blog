# frozen_string_literal: true

module Substack
  # Builds and detects the featured-quote blocks. Each quotation renders as a
  # three-block unit: a lead (a native post-embed card when the quotation has a
  # post_embed snapshot, else an h4 heading linking the post), a blockquote of the
  # italicised quote (a 🔗 to the original comment then an em-dash and the linked
  # commenter, all inline), and a centred "." spacer paragraph. The template's
  # syncQuotations directive expands into N of these; the rotation job finds the
  # run in a draft and swaps them for fresh ones.
  module QuotationBlock
    module_function

    def unit(quotation)
      [lead(quotation), blockquote(quotation), spacer]
    end

    # The heading-only unit (no embed card) — kept for the heading fallback and
    # for callers/tests that want the plain triplet.
    def build(quotation)
      [heading(quotation), blockquote(quotation), spacer]
    end

    def lead(quotation)
      card(quotation) || heading(quotation)
    end

    # Substack's native "small" post-embed, from the stored snapshot; nil when the
    # quotation has no snapshot (falls back to the heading). nodeId is per-node.
    def card(quotation)
      return nil if quotation.post_embed.blank?

      { "type" => "digestPostEmbed", "attrs" => quotation.post_embed.merge("nodeId" => SecureRandom.uuid) }
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

    # Replace the contiguous run of quotation triplets in an existing draft body
    # with fresh ones (same count), in place. Returns the content unchanged when
    # no run is found.
    def rotate(content, quotations)
      start = (0...content.size).find { |i| triplet_at?(content, i) }
      return content unless start

      length = 0
      length += 1 while triplet_at?(content, start + length * 3)
      fresh = quotations.first(length).flat_map { |quotation| unit(quotation) }
      content[0...start] + fresh + content[(start + length * 3)..]
    end

    # A quotation unit: a lead (post-embed card or a post-linking heading), an
    # em-blockquote, then a paragraph (the author line, or a bare spacer). The
    # third block is only required to be a paragraph — the reference draft's
    # card units carry a plain "." there rather than a linked author.
    def triplet_at?(content, index)
      quotation_lead?(content[index]) &&
        blockquote_em?(content[index + 1]) &&
        paragraph?(content[index + 2])
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
