# frozen_string_literal: true

namespace :substack do
  # The canonical post whose subtitle + footer boilerplate we mirror onto every
  # Substack draft. Re-run capture_footer against another draft to change it.
  REFERENCE_FOOTER_DRAFT_ID = "206216505"

  desc "Capture subtitle + footer boilerplate from a reference draft into SubstackSyncConfig"
  task :capture_footer, [:draft_id] => :environment do |_t, args|
    footer = Substack::FooterCapturer.execute(draft_id: args[:draft_id].presence || REFERENCE_FOOTER_DRAFT_ID)
    puts "Captured subtitle + #{footer.size} footer blocks."
  end

  desc "Seed the footer only if not already captured — safe to run on every deploy"
  task seed_footer: :environment do
    if SubstackSyncConfig.instance.footer_json.present?
      puts "Substack footer already seeded; skipping."
    else
      Rake::Task["substack:capture_footer"].invoke
    end
  rescue => e
    # Never fail a deploy over a transient Substack/API issue; next deploy retries.
    warn "[substack:seed_footer] skipped: #{e.message}"
  end

  desc "Re-resolve existing Reply Tracker records from their reply URL (backfills previews, corrects target URLs)"
  task backfill_replies: :environment do
    SubstackReply.find_each do |reply|
      r = Substack::ReplyResolver.execute(reply_url: reply.comment_url)
      reply.update!(
        target_url:     r.target_url,
        author_name:    r.author_name,
        author_handle:  r.author_handle,
        author_user_id: r.author_user_id,
        replied_at:     r.replied_at.presence || reply.replied_at,
        target_preview: r.target_preview,
        reply_preview:  r.reply_preview
      )
      puts "backfilled ##{reply.id} → @#{r.author_handle}: #{r.target_preview.to_s[0, 40].inspect}"
    rescue => e
      warn "skipped ##{reply.id} (#{reply.comment_url}): #{e.message}"
    ensure
      sleep 0.5 # gentle pacing over the Substack API
    end
    puts "done."
  end
end
