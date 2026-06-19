# frozen_string_literal: true

# Helpers for turning Substack Note URLs and fetched comment payloads into the
# pieces we store: the comment id, the rich ProseMirror body, a plaintext
# rendering (for matching/display), and the timestamp. Field extraction is kept
# tolerant of Substack's response-shape variants (confirmed by substack:blizzard:proof).
module Substack
  module NoteParser
    module_function

    COMMENT_ID = %r{/note/c-(\d+)}

    def comment_id_from_url(url)
      url.to_s[COMMENT_ID, 1]
    end

    # The fetched comment object, regardless of whether the API wraps it.
    def comment(payload)
      payload["item"]&.dig("comment") || payload["comment"] || payload
    end

    def body_json(comment)
      comment["body_json"] || comment["bodyJson"]
    end

    def timestamp(comment)
      comment["date"] || comment["createdAt"] || comment["created_at"]
    end

    # Flatten a ProseMirror doc to readable plaintext (paragraphs joined by \n).
    def plaintext(body_json)
      return "" if body_json.blank?

      blocks = (body_json["content"] || []).map { |node| node_text(node) }
      blocks.reject(&:empty?).join("\n")
    end

    # Whitespace-insensitive key for matching two note bodies.
    def normalize(text)
      text.to_s.gsub(/\s+/, " ").strip
    end

    def node_text(node)
      return node["text"].to_s if node["type"] == "text"

      (node["content"] || []).map { |child| node_text(child) }.join
    end

    # All href values from link marks in the doc.
    def link_hrefs(body_json, acc = [])
      return acc if body_json.blank?

      (body_json["marks"] || []).each do |mark|
        href = mark.dig("attrs", "href")
        acc << href if mark["type"] == "link" && href.present?
      end
      (body_json["content"] || []).each { |child| link_hrefs(child, acc) }
      acc
    end

    # The slug after /p/ in a Substack post URL, used to compare a note's linked
    # post against the categorization's canonical #url regardless of host/query.
    def post_slug(url)
      url.to_s[%r{/p/([^/?#]+)}, 1]
    end
  end
end
