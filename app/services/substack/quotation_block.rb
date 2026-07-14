# frozen_string_literal: true

module Substack
  # Builds and detects the mirror-managed "featured quote" block appended to a
  # Substack post body: a blockquote of the quotation plus an attribution line
  # ("By <author>, on <post>"). The attribution's shape is the detection
  # signature, so an old block can be found and swapped for a fresh one.
  module QuotationBlock
    module_function

    ATTRIBUTION = /\ABy .+, on .+/m

    def build(quotation)
      {
        "type"    => "blockquote",
        "content" => [
          paragraph([text("“#{quotation.quotation}”")]),
          paragraph(attribution(quotation))
        ]
      }
    end

    # True for a block we produced: a blockquote whose last paragraph reads
    # "By …, on …" and carries a link (so real content blockquotes don't match).
    def matches?(block)
      return false unless block.is_a?(Hash) && block["type"] == "blockquote"

      last = Array(block["content"]).last
      last.is_a?(Hash) && paragraph_text(last).match?(ATTRIBUTION) && linked?(last)
    end

    # Strip any existing quotation block from a doc's content array and append a
    # fresh one (or just strip, when there's no quotation to show).
    def apply(content, quotation)
      stripped = Array(content).reject { |block| matches?(block) }
      quotation ? stripped + [build(quotation)] : stripped
    end

    def paragraph(content)
      { "type" => "paragraph", "attrs" => { "textAlign" => "left" }, "content" => content }
    end

    def text(string, href: nil)
      node = { "type" => "text", "text" => string.to_s }
      node["marks"] = [link(href)] if href.present?
      node
    end

    def link(href)
      { "type" => "link", "attrs" => { "href" => href, "target" => "_blank",
                                       "rel" => "noopener noreferrer nofollow", "class" => nil } }
    end

    def attribution(quotation)
      [
        text("By "),
        text(quotation.author_name.presence || "a reader", href: quotation.author_url),
        text(", on "),
        text(quotation.post_title.presence || "a post", href: quotation.post_url)
      ]
    end

    def paragraph_text(node)
      Array(node["content"]).filter_map { |n| n["text"] }.join
    end

    def linked?(node)
      Array(node["content"]).any? { |n| Array(n["marks"]).any? { |m| m["type"] == "link" } }
    end
  end
end
