# frozen_string_literal: true

module Substack
  # Locates where the mirror-managed below-body template starts in a Substack
  # draft's content (everything above it is the post body).
  #
  # Current layout: the template starts at the divider (horizontal rule)
  # directly above the "😘 THANK YOU 😘" heading, and runs to the end — the
  # "This post also moonwalks resplendent twixt" platform-links section is now
  # its last part.
  #
  # Older layouts are still recognised, so drafts not yet re-synced split
  # correctly: the template used to start at the platform-links heading (a
  # heading whose first link reads "My website"), pulled back over the
  # unlinked, centre-aligned headings directly above it (its "This post ALSO
  # moonwalks…" intro and "." spacer; synced body headings never carry a
  # textAlign), and before that at an "Original:" heading. Whichever marker
  # comes first in the draft wins.
  module TemplateBoundary
    module_function

    THANK_YOU_HEADING = "THANK YOU"
    LINKS_ROW_LEAD    = "My website"

    def index(content)
      [thank_you_index(content), links_section_index(content), legacy_original_index(content)].compact.min
    end

    # The divider above the THANK YOU heading (or the heading itself, if no
    # divider sits directly above it).
    def thank_you_index(content)
      heading = content.index { |block| heading?(block) && text_of(block).include?(THANK_YOU_HEADING) }
      return unless heading

      heading.positive? && divider?(content[heading - 1]) ? heading - 1 : heading
    end

    def links_section_index(content)
      anchor = content.index { |block| links_row?(block) }
      return unless anchor

      anchor -= 1 while anchor.positive? && lead_in_heading?(content[anchor - 1])
      anchor
    end

    def legacy_original_index(content)
      content.index { |block| legacy_original?(block) }
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

    def divider?(block)
      block.is_a?(Hash) && block["type"] == "horizontal_rule"
    end

    def link_mark?(node)
      Array(node["marks"]).any? { |mark| mark["type"] == "link" }
    end

    def text_of(block)
      Array(block["content"]).flat_map { |n| [n["text"]] + Array(n["content"]).map { |x| x["text"] } }.compact.join
    end
  end
end
