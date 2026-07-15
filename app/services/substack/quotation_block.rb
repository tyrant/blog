# frozen_string_literal: true

module Substack
  # Builds and detects the featured-quote blocks. Each quotation renders as a
  # triplet: an h4 heading linking the post it was left on, a blockquote of the
  # italicised quote, and a right-aligned line linking the commenter. The
  # template's syncQuotations directive expands into N of these; the rotation
  # job finds the run of triplets in a draft and swaps them for fresh ones.
  module QuotationBlock
    module_function

    def build(quotation)
      [heading(quotation), blockquote(quotation), attribution(quotation)]
    end

    def heading(quotation)
      { "type" => "heading", "attrs" => { "textAlign" => nil, "level" => 4 },
        "content" => [text(quotation.post_title, href: quotation.post_url)] }
    end

    def blockquote(quotation)
      { "type" => "blockquote", "content" => [
        { "type" => "paragraph", "attrs" => { "textAlign" => "left" },
          "content" => [text("“#{quotation.quotation}”", marks: [{ "type" => "em" }])] }
      ] }
    end

    def attribution(quotation)
      { "type" => "paragraph", "attrs" => { "textAlign" => "right" },
        "content" => [text(quotation.author_name, href: quotation.author_url)] }
    end

    # Replace the contiguous run of quotation triplets in an existing draft body
    # with fresh ones (same count), in place. Returns the content unchanged when
    # no run is found.
    def rotate(content, quotations)
      start = (0...content.size).find { |i| triplet_at?(content, i) }
      return content unless start

      length = 0
      length += 1 while triplet_at?(content, start + length * 3)
      fresh = quotations.first(length).flat_map { |quotation| build(quotation) }
      content[0...start] + fresh + content[(start + length * 3)..]
    end

    def triplet_at?(content, index)
      heading_post_link?(content[index]) &&
        blockquote_em?(content[index + 1]) &&
        author_right?(content[index + 2])
    end

    def heading_post_link?(block)
      block.is_a?(Hash) && block["type"] == "heading" && link_href(block).to_s.include?("/p/")
    end

    def blockquote_em?(block)
      return false unless block.is_a?(Hash) && block["type"] == "blockquote"

      para = Array(block["content"]).first
      Array(para&.dig("content")).any? { |node| Array(node["marks"]).any? { |mark| mark["type"] == "em" } }
    end

    def author_right?(block)
      block.is_a?(Hash) && block["type"] == "paragraph" &&
        block.dig("attrs", "textAlign") == "right" &&
        link_href(block).to_s.include?("substack.com/@")
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
