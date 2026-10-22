# frozen_string_literal: true

# Captures the whole below-body post template from a reference Substack draft
# into SubstackSyncConfig#footer_json, so PostSyncer can resolve it per post.
# The template is every block from the platform-links section onward (the
# body is above it; see TemplateBoundary); on the way in, the dynamic parts
# become directives:
#   the "My website · Facebook · …" row → syncPlatformLinks {textAlign, level}
#   a legacy "Original:" heading        → syncOriginalLink
#   the run of quotation triplets    → syncQuotations {count}
#   configured conditional sections  → syncIf {tag}
# Only footer_json is written — the subtitle fields are left untouched.
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
      substitute_links_row!(template)
      substitute_quotations!(template)
      wrap_conditionals!(template)

      SubstackSyncConfig.instance.update!(footer_json: template)
      template
    end

    private

    def below_body(content)
      index = Substack::TemplateBoundary.index(content)
      raise "No \"#{Substack::TemplateBoundary::LINKS_ROW_LEAD}\" links heading (or legacy Original: link) found in draft #{@draft_id}" unless index

      content[index..].dup
    end

    # The links row is rebuilt per post from its categorizations; keep only its
    # heading attrs (alignment, level). Legacy templates anchor on "Original:".
    def substitute_links_row!(template)
      row = template.index { |block| Substack::TemplateBoundary.links_row?(block) }
      if row
        template[row] = { "type" => "syncPlatformLinks", "attrs" => template[row]["attrs"].to_h.slice("textAlign", "level") }
      else
        template[0] = { "type" => "syncOriginalLink" }
      end
    end

    def substitute_quotations!(template)
      start = (0...template.size).find { |i| Substack::QuotationBlock.triplet_at?(template, i) }
      return unless start

      count, stop = Substack::QuotationBlock.walk_units(template, start)
      template[start...stop] = [{ "type" => "syncQuotations", "attrs" => { "count" => count } }]
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
