# frozen_string_literal: true

# Captures the publication-wide subtitle + footer boilerplate from a reference
# Substack draft into SubstackSyncConfig, so PostSyncer can append them to every
# mirrored post. The footer is every block from the first subscribeWidget onward
# (subscribe CTA through the "Subscribe now" button).
module Substack
  class FooterCapturer
    include ServiceInterface

    arguments :draft_id, client: nil

    def execute
      @client ||= Substack::Client.new
      draft = @client.get_draft(@draft_id)
      content = Array(JSON.parse(draft["draft_body"].to_s)["content"])
      index = content.index { |block| block["type"] == "subscribeWidget" }
      raise "No subscribeWidget block found in draft #{@draft_id}" unless index

      footer = content[index..]
      SubstackSyncConfig.instance.update!(subtitle: draft["draft_subtitle"], footer_json: footer)
      footer
    end
  end
end
