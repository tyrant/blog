# frozen_string_literal: true

module Substack
  # Locates where the mirror-managed below-body template starts in a Substack
  # draft's content (everything above it is the post body). The anchor is the
  # platform-links heading — a heading whose first link reads "My website" —
  # pulled back over the unlinked, centre-aligned headings directly above it
  # (its "This post ALSO moonwalks…" intro and "." spacer; synced body headings
  # never carry a textAlign). Drafts synced before the links row still mark the
  # boundary with an "Original:" heading, which is matched as a fallback.
  module TemplateBoundary
    module_function

    LINKS_ROW_LEAD = "My website"

    def index(content)
      anchor = content.index { |block| links_row?(block) }
      return content.index { |block| legacy_original?(block) } unless anchor

      anchor -= 1 while anchor.positive? && lead_in_heading?(content[anchor - 1])
      anchor
    end

    def links_row?(block)
      return false unless heading?(block)

      first_link = Array(block["content"]).find { |node| link_mark?(node) }
      first_link && first_link["text"].to_s.strip == LINKS_ROW_LEAD
    end

    def legacy_original?(block)
      heading?(block) && text_of(block).strip.start_with?("Original:")
    end

    def lead_in_heading?(block)
      heading?(block) && block.dig("attrs", "textAlign") == "center" &&
        Array(block["content"]).none? { |node| link_mark?(node) }
    end

    def heading?(block)
      block.is_a?(Hash) && block["type"] == "heading"
    end

    def link_mark?(node)
      Array(node["marks"]).any? { |mark| mark["type"] == "link" }
    end

    def text_of(block)
      Array(block["content"]).flat_map { |n| [n["text"]] + Array(n["content"]).map { |x| x["text"] } }.compact.join
    end
  end
end
