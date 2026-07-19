# frozen_string_literal: true

# Builds a Substack Note body_json from a SubstackQuotation, for the blizzard's
# quotation reposts. Adapted to the Note schema (blockquote + bold/italic/link
# marks; Notes have no heading or paragraph alignment): a bold "Review:" label, a
# bold post-title link, the italic quote trailed by a 🔗 to the original comment,
# the linked author, and a "More reviews" link. The post itself rides along as a
# preview-card attachment (added by the ticker).
module Substack
  module Blizzard
    module QuotationNote
      module_function

      REVIEWS_URL = "https://mikeyclarke.substack.com/p/reviews"

      def build(quotation)
        { "type" => "doc", "attrs" => { "schemaVersion" => "v1" },
          "content" => [label, title(quotation), quote(quotation), attribution(quotation), more_reviews] }
      end

      def label
        { "type" => "paragraph", "content" => [text("Review:", marks: [{ "type" => "bold" }])] }
      end

      def title(quotation)
        { "type" => "paragraph",
          "content" => [text(quotation.post_title, marks: [{ "type" => "bold" }, link(quotation.post_url)])] }
      end

      def quote(quotation)
        nodes = [text("“#{quotation.quotation}”", marks: [{ "type" => "italic" }])]
        if quotation.comment_url.present?
          nodes << text(" ")
          nodes << text("🔗", marks: [link(quotation.comment_url)])
        end
        { "type" => "blockquote", "content" => [{ "type" => "paragraph", "content" => nodes }] }
      end

      def attribution(quotation)
        { "type" => "paragraph",
          "content" => [text("— "), text(quotation.author_name, marks: [link(quotation.author_url)])] }
      end

      # Substack strips an explicit link mark to the reviews page (a page, not a
      # card-able post), but auto-linkifies a bare URL sitting in plain text — so
      # emit the URL unmarked in parens and let Substack turn it into the link.
      def more_reviews
        { "type" => "paragraph", "content" => [text("More at the Reviews Page (#{REVIEWS_URL})")] }
      end

      def text(string, marks: [])
        node = { "type" => "text", "text" => string.to_s }
        node["marks"] = marks if marks.any?
        node
      end

      def link(href)
        { "type" => "link", "attrs" => { "href" => href } }
      end
    end
  end
end
