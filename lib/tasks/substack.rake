# frozen_string_literal: true

namespace :substack do
  desc "Capture the standard subtitle + footer blocks from a reference Substack draft into SubstackSyncConfig"
  task :capture_footer, [:draft_id] => :environment do |_t, args|
    abort "usage: rake substack:capture_footer[DRAFT_ID]" if args[:draft_id].blank?

    draft = Substack::Client.new.get_draft(args[:draft_id])
    doc   = JSON.parse(draft["draft_body"].to_s)
    index = Array(doc["content"]).index { |block| block["type"] == "subscribeWidget" }
    abort "No subscribeWidget block found in draft #{args[:draft_id]}" unless index

    footer = doc["content"][index..]
    SubstackSyncConfig.instance.update!(subtitle: draft["draft_subtitle"], footer_json: footer)
    puts "Captured subtitle (#{draft["draft_subtitle"].to_s.length} chars) + #{footer.size} footer blocks."
  end
end
