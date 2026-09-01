# frozen_string_literal: true

module Substack
  # Resolves the stored post-body-suffix template (SubstackSyncConfig#footer_json)
  # for a given post: literal ProseMirror blocks pass through untouched, while
  # three directive nodes expand at sync time (and never reach Substack):
  #   {"type": "syncOriginalLink"}                          → the "Original: <url>" heading
  #   {"type": "syncQuotations", "attrs": {"count": 3}}     → N random quotation triplets
  #   {"type": "syncIf", "attrs": {"tag": "…"}, "content":[…]} → its blocks, only if the post is so tagged
  # Literal text nodes also get their "N-and-counting" quotation tally refreshed
  # to the live SubstackQuotation.featurable.count on every resolve.
  class TemplateResolver
    # Matches the live count's digits regardless of phrasing around "counting"
    # ("141-and-counting", "142 gems and counting", …) — digits followed,
    # within a short run of non-digit filler, by "and counting"/"and-counting".
    QUOTATION_COUNT_PATTERN = /\d+(?=[^\d]{0,20}and[\s-]counting)/i

    def self.resolve(blocks, post:, quotations: nil)
      new(post: post, quotations: quotations).resolve(blocks)
    end

    def initialize(post:, quotations: nil)
      @post = post
      @quotations = quotations
    end

    def resolve(blocks)
      Array(blocks).flat_map { |block| resolve_block(block) }
    end

    private

    def resolve_block(block)
      case block["type"]
      when "syncOriginalLink" then [original_link_heading]
      when "syncQuotations"   then quotation_blocks(block.dig("attrs", "count") || 3)
      when "syncIf"           then resolve_conditional(block)
      else [substitute_quotation_count(block)]
      end
    end

    # The captured footer text includes a live "N-and-counting" quotation tally
    # (e.g. "boasts 141-and-counting"), frozen at whatever it read when the
    # footer was last captured — keep it current on every resolve instead.
    def substitute_quotation_count(node)
      return node unless node.is_a?(Hash)

      node = node.merge("text" => node["text"].gsub(QUOTATION_COUNT_PATTERN, quotation_count.to_s)) if
        node["type"] == "text" && node["text"].to_s.match?(QUOTATION_COUNT_PATTERN)
      node = node.merge("content" => node["content"].map { |child| substitute_quotation_count(child) }) if
        node["content"].is_a?(Array)
      node
    end

    def quotation_count
      @quotation_count ||= SubstackQuotation.featurable.count
    end

    def resolve_conditional(block)
      @post.tags.exists?(name: block.dig("attrs", "tag")) ? resolve(block["content"]) : []
    end

    def quotation_blocks(count)
      random_quotations(count).flat_map { |quotation| Substack::QuotationBlock.unit(quotation) }
    end

    def random_quotations(count)
      return @quotations.first(count) if @quotations

      SubstackQuotation.sample_excluding(own_substack_url, count)
    end

    def own_substack_url
      @own_substack_url ||= @post.categorizations.joins(:category)
        .find_by(comfy_cms_categories: { label: "Substack" })&.url
    end

    def original_link_heading
      url = @post.url.to_s.sub(%r{\A//}, "https://")
      {
        "type" => "heading", "attrs" => { "textAlign" => "left", "level" => 5 },
        "content" => [
          { "type" => "text", "text" => "Original: " },
          { "type" => "text", "text" => url, "marks" => [{
            "type" => "link", "attrs" => { "href" => url, "target" => "_blank",
                                           "rel" => "noopener noreferrer nofollow", "class" => nil }
          }] }
        ]
      }
    end
  end
end
