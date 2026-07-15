# frozen_string_literal: true

module Substack
  # Resolves the stored post-body-suffix template (SubstackSyncConfig#footer_json)
  # for a given post: literal ProseMirror blocks pass through untouched, while
  # three directive nodes expand at sync time (and never reach Substack):
  #   {"type": "syncOriginalLink"}                          → the "Original: <url>" heading
  #   {"type": "syncQuotations", "attrs": {"count": 3}}     → N random quotation triplets
  #   {"type": "syncIf", "attrs": {"tag": "…"}, "content":[…]} → its blocks, only if the post is so tagged
  class TemplateResolver
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
      else [block]
      end
    end

    def resolve_conditional(block)
      @post.tags.exists?(name: block.dig("attrs", "tag")) ? resolve(block["content"]) : []
    end

    def quotation_blocks(count)
      random_quotations(count).flat_map { |quotation| Substack::QuotationBlock.build(quotation) }
    end

    def random_quotations(count)
      pool = @quotations || SubstackQuotation
        .where.not(post_url: [nil, ""]).where.not(author_url: [nil, ""])
        .order(Arel.sql("RANDOM()")).limit(count)
      pool.first(count)
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
