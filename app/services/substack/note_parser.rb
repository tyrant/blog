# frozen_string_literal: true

# Helpers for turning Substack Note URLs and fetched comment payloads into the
# pieces we store: the comment id, the rich ProseMirror body, a plaintext
# rendering (for matching/display), and the timestamp. Field extraction is kept
# tolerant of Substack's response-shape variants (confirmed by substack:blizzard:proof).
module Substack
  module NoteParser
    module_function

    COMMENT_ID = %r{/note/c-(\d+)}

    # Substack renders note timestamps in the viewer's local zone (NZ), e.g.
    # "21 Jun at 19:00". Manual paste-back times are entered in that form.
    LOCAL_ZONE = "Pacific/Auckland"

    def comment_id_from_url(url)
      url.to_s[COMMENT_ID, 1]
    end

    # Parse a Substack footer timestamp ("21 Jun at 19:00", or an ISO string)
    # into a UTC ISO8601 string. Returns nil if unparseable.
    def parse_human_timestamp(text)
      return nil if text.blank?

      Time.find_zone(LOCAL_ZONE).parse(text.to_s.gsub(/\bat\b/i, " "))&.utc&.iso8601
    rescue ArgumentError
      nil
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

    # The note's Likes count (Substack's ❤ reaction). reaction_count is the total;
    # fall back to summing the per-emoji reactions breakdown.
    def likes(comment)
      return comment["reaction_count"].to_i if comment&.key?("reaction_count")

      Array(comment&.dig("reactions")&.values).sum(&:to_i)
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

    # A new note lives on the same profile as the group's existing notes, so build
    # its URL by swapping the comment id of a template note URL.
    def build_note_url(template_url, new_id)
      old = comment_id_from_url(template_url)
      old ? template_url.sub("c-#{old}", "c-#{new_id}") : "https://substack.com/note/c-#{new_id}"
    end

    # Append the canonical post URL as a trailing link paragraph to a note's
    # body_json, so reposts end with the post link. Idempotent (skips if that post
    # is already linked). Returns the (possibly unchanged) body_json.
    def append_post_url(body_json, post_url)
      return body_json if body_json.blank? || post_url.blank?

      slug = post_slug(post_url)
      return body_json if slug && link_hrefs(body_json).any? { |h| post_slug(h) == slug }

      doc = body_json.deep_dup
      doc["content"] = Array(doc["content"]) + [{
        "type"    => "paragraph",
        "content" => [{ "type" => "text", "text" => post_url, "marks" => [{ "type" => "link", "attrs" => { "href" => post_url } }] }]
      }]
      doc
    end

    # Build a minimal ProseMirror doc from plaintext: plain paragraphs split on
    # newlines, no formatting (lossy — bold/italic/links can't be recovered).
    def text_to_body_json(text)
      {
        "type"    => "doc",
        "attrs"   => { "schemaVersion" => "v1" },
        "content" => text.to_s.split("\n").map do |line|
          para = { "type" => "paragraph" }
          para["content"] = [{ "type" => "text", "text" => line }] unless line.empty?
          para
        end
      }
    end

    # Inverse of append_post_url: drop a trailing paragraph that is just the post
    # URL, used when posting via API (the post becomes a card attachment instead).
    def strip_post_url(body_json, post_url)
      return body_json if body_json.blank? || post_url.blank?

      content = Array(body_json["content"])
      last = content.last
      return body_json unless last && last["type"] == "paragraph" && node_text(last).strip == post_url.strip

      doc = body_json.deep_dup
      doc["content"] = content[0...-1]
      doc
    end
  end
end
