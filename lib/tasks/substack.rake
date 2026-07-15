# frozen_string_literal: true

namespace :substack do
  # The canonical draft whose below-body template we mirror onto every Substack
  # post. Re-run capture_footer against another draft to change it.
  REFERENCE_FOOTER_DRAFT_ID = "206980888"

  desc "Capture the below-body template from a reference draft into SubstackSyncConfig"
  task :capture_footer, [:draft_id] => :environment do |_t, args|
    template = Substack::TemplateCapturer.execute(draft_id: args[:draft_id].presence || REFERENCE_FOOTER_DRAFT_ID)
    puts "Captured subtitle + #{template.size}-block template."
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

  desc "Scrape every Substack-linked post for its tags and mirror them into Comfy Tags"
  task import_tags: :environment do
    result = Substack::TagImporter.execute(progress: ->(msg) { puts msg })
    puts "done — #{result.posts_scanned} posts scanned, #{result.tags_seen} tags, #{result.links_created} links created."
  end

  desc "Migrate the Whimsy/NSFW/Shite Advice categories to Tags (additive; categories left intact)"
  task migrate_category_tags: :environment do
    result = CategoryTagMigrator.execute
    puts "done — tags #{result.tags.inspect}, #{result.links_created} links created."
  end

  desc "Delete the migrated topical categories once their Tag links are in parity (Phase 2)"
  task retire_category_tags: :environment do
    result = TopicalCategoryRetirer.execute
    puts "deleted: #{result.deleted.inspect}, skipped (not in parity): #{result.skipped.inspect}"
  end

  desc "Add class=caption to Comfy paragraphs matching existing Substack captions (dry-run unless COMMIT=1)"
  task harvest_captions: :environment do
    commit = ENV["COMMIT"] == "1"
    results = Substack::CaptionHarvester.execute(commit: commit, progress: lambda { |r|
      note = r.unmatched.any? ? " UNMATCHED=#{r.unmatched.map { |c| c[0, 30] }.inspect}" : ""
      puts "  ##{r.post_id} #{r.slug.to_s[0, 32].ljust(32)} captions=#{r.captions} marked=#{r.marked}#{note}"
    })
    puts "\n#{commit ? 'Committed' : 'Dry run'}. #{results.size} posts with captions, " \
         "#{results.sum(&:marked)} paragraphs marked, #{results.sum { |r| r.unmatched.size }} unmatched."
  end

  desc "Audit synced posts for manual Substack-only tweaks a resync would clobber (read-only)"
  task scan_divergences: :environment do
    findings = Substack::DivergenceScanner.execute(progress: lambda { |f|
      next if f.flags.empty?

      details = []
      details << "sizes=#{f.image_sizes.inspect}" if f.image_sizes.present?
      details << "captions=#{f.captions.map { |c| c.to_s[0, 30] }.inspect}" if f.captions.present?
      puts "  ##{f.post_id} #{f.slug.to_s[0, 34].ljust(34)} [#{f.flags.join(',')}] #{details.join(' ')}"
    })
    flagged = findings.reject { |f| f.flags.empty? }
    tally = Hash.new(0)
    flagged.each { |f| f.flags.each { |flag| tally[flag.sub(/[+-]\d+$/, '').sub(/^ERROR.*/, 'ERROR')] += 1 } }
    puts "\n#{findings.size} synced posts scanned, #{flagged.size} with divergences."
    puts "by flag: #{tally.sort_by { |_k, v| -v }.to_h.inspect}"
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
        reply_preview:  r.reply_preview,
        ancestor_path:  r.ancestor_path
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
