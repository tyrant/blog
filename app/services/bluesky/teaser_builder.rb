# frozen_string_literal: true

# Builds a Bluesky teaser under the 300-grapheme cap: a lead line, the post
# title, and the canonical URL, with a facet marking the URL's UTF-8 byte span
# so it renders as a clickable link. Bluesky counts the post length in graphemes
# but indexes facets in bytes — the two must not be conflated.
module Bluesky
  class TeaserBuilder
    include ServiceInterface

    LIMIT = 300

    arguments :post, :url, lead: ""

    def execute
      prefix = [@lead.presence, @post.title.to_s].compact.join("\n\n")
      # Reserve room for the "\n\n" separator (2 graphemes) plus the URL, trimming
      # the prefix on grapheme boundaries so the whole thing lands at <= 300.
      budget = LIMIT - grapheme_length(@url) - 2
      text   = "#{truncate_graphemes(prefix, budget)}\n\n#{@url}"

      { text: text, facets: [link_facet(text, @url)] }
    end

    private

    def grapheme_length(string)
      string.grapheme_clusters.length
    end

    def truncate_graphemes(string, max)
      return "" if max <= 0

      clusters = string.grapheme_clusters
      return string if clusters.length <= max

      clusters.first(max - 1).join + "…"
    end

    def link_facet(text, url)
      byte_start = text[0...text.index(url)].bytesize
      {
        "index"    => { "byteStart" => byte_start, "byteEnd" => byte_start + url.bytesize },
        "features" => [{ "$type" => "app.bsky.richtext.facet#link", "uri" => url }]
      }
    end
  end
end
