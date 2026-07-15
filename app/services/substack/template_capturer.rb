# frozen_string_literal: true

# Captures the whole below-body post template from a reference Substack draft
# into SubstackSyncConfig#footer_json, so PostSyncer can resolve it per post.
# The template is every block from the "Original:" link onward (the body is
# above it); on the way in, the dynamic parts become directives:
#   the Original heading            → syncOriginalLink
#   the run of quotation triplets    → syncQuotations {count}
#   configured conditional sections  → syncIf {tag}
# Also stores the draft's subtitle as the "Shite Advice" subtitle.
module Substack
  class TemplateCapturer
    include ServiceInterface

    arguments :draft_id, client: nil

    # Sections wrapped in a tag conditional: a heading whose text includes the
    # phrase, through to (not including) the next subscribe block, gated on the
    # tag. Extend this list to add more conditional sections.
    CONDITIONALS = [{ heading: "Bullshit Emeritus", tag: "Shite Advice" }].freeze

    def execute
      @client ||= Substack::Client.new
      draft = @client.get_draft(@draft_id)
      content = Array(JSON.parse(draft["draft_body"].to_s)["content"])

      template = below_body(content)
      template[0] = { "type" => "syncOriginalLink" }
      substitute_quotations!(template)
      wrap_conditionals!(template)

      SubstackSyncConfig.instance.update!(subtitle: draft["draft_subtitle"], footer_json: template)
      template
    end

    private

    def below_body(content)
      index = content.index { |block| block["type"] == "heading" && block_text(block).strip.start_with?("Original:") }
      raise "No Original: link found in draft #{@draft_id}" unless index

      content[index..].dup
    end

    def substitute_quotations!(template)
      start = (0...template.size).find { |i| Substack::QuotationBlock.triplet_at?(template, i) }
      return unless start

      count = 0
      count += 1 while Substack::QuotationBlock.triplet_at?(template, start + count * 3)
      template[start, count * 3] = [{ "type" => "syncQuotations", "attrs" => { "count" => count } }]
    end

    def wrap_conditionals!(template)
      CONDITIONALS.each do |rule|
        start = template.index { |b| b["type"] == "heading" && block_text(b).include?(rule[:heading]) }
        next unless start

        stop = (start...template.size).find { |i| template[i]["type"] == "subscribeWidget" } || template.size
        template[start...stop] = [{ "type" => "syncIf", "attrs" => { "tag" => rule[:tag] }, "content" => template[start...stop] }]
      end
    end

    def block_text(block)
      Array(block["content"]).flat_map { |n| [n["text"]] + Array(n["content"]).map { |x| x["text"] } }.compact.join
    end
  end
end
