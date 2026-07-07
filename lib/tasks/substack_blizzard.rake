# frozen_string_literal: true

namespace :substack do
  namespace :blizzard do
    # Directive gate: confirm we can extract, store, and losslessly repost rich
    # text (bold/italic/link) via the internal API. Reads one existing note to pin
    # field names, posts a throwaway note, reads it back, then deletes it.
    #
    #   NOTE_ID=267421089 rails substack:blizzard:proof   # explicit note to read
    desc "Prove Substack rich-text read/create/delete round-trip (posts then deletes a test note)"
    task proof: :environment do
      client = Substack::Client.new

      note_id = ENV["NOTE_ID"].presence || begin
        url = Comfy::Cms::Categorization
          .joins(:category).where(comfy_cms_categories: { label: "Substack" })
          .map { |c| c.data["notes"] }.compact.flatten.find { |u| Substack::NoteParser.comment_id_from_url(u) }
        Substack::NoteParser.comment_id_from_url(url)
      end

      puts "── READ existing note c-#{note_id} ──"
      payload = client.get_note(note_id)
      comment = Substack::NoteParser.comment(payload)
      puts "comment keys: #{comment.keys.sort.join(', ')}"
      puts "timestamp:    #{Substack::NoteParser.timestamp(comment).inspect}"
      puts "plaintext:    #{Substack::NoteParser.plaintext(Substack::NoteParser.body_json(comment)).inspect}"
      puts "body_json:    #{Substack::NoteParser.body_json(comment).to_json[0, 400]}"

      puts "\n── CREATE throwaway note (bold + italic + link) ──"
      sent = proof_body_json
      created = Substack::NoteParser.comment(client.create_note(sent))
      created_id = created["id"]
      puts "created id:   #{created_id.inspect}"
      puts "created at:   #{Substack::NoteParser.timestamp(created).inspect}"

      puts "\n── READ BACK and compare marks ──"
      back = Substack::NoteParser.comment(client.get_note(created_id))
      marks = collect_marks(Substack::NoteParser.body_json(back))
      puts "marks seen:   #{marks.to_a.sort.join(', ')}"
      %w[bold italic link].each do |m|
        ok = marks.any? { |seen| seen.include?(m) }
        puts "  #{ok ? '✓' : '✗'} #{m}#{' (check mark name above)' unless ok}"
      end

      puts "\n── DELETE throwaway note ──"
      client.delete_note(created_id)
      puts "deleted c-#{created_id}. Done."
    end

    desc "Report blizzard backfill per Substack categorization (no writes)"
    task backfill_dry_run: :environment do
      BlizzardBackfillRunner.run(commit: false)
    end

    desc "Backfill data[blizzard] from data[notes] for every Substack categorization"
    task backfill: :environment do
      BlizzardBackfillRunner.run(commit: true)
    end

    desc "Report appending the canonical post URL to each blizzard body_json (no writes)"
    task append_urls_dry_run: :environment do
      BlizzardUrlAppender.run(commit: false)
    end

    desc "Append the canonical post URL (as a trailing link) to each blizzard body_json"
    task append_urls: :environment do
      BlizzardUrlAppender.run(commit: true)
    end

    desc "Report generating plain body_json from text for entries that lack it (no writes)"
    task fill_missing_body_json_dry_run: :environment do
      BlizzardBodyJsonFiller.run(commit: false)
    end

    desc "Generate plain body_json from text for blizzard entries that have none"
    task fill_missing_body_json: :environment do
      BlizzardBodyJsonFiller.run(commit: true)
    end

    # Run these LOCALLY (residential IP) — server-side note POSTs are Cloudflare-blocked.
    # One tick asks prod for the next weighted repost (prod gates itself to one per
    # interval_minutes), posts it, and confirms back. Most ticks are no-ops.
    # Intended to run on a local cron every ~2 min.
    #   rails substack:blizzard:tick_dry_run
    #   rails substack:blizzard:tick
    # Env: BLIZZARD_PROD_URL (default https://mikeyclarke.co.nz),
    #      BLIZZARD_ADMIN_USER / BLIZZARD_ADMIN_PASS (default: app admin creds).
    desc "Preview the next weighted repost (no Note created)"
    task tick_dry_run: :environment do
      BlizzardRepostTick.run(commit: false)
    end

    desc "Post the next weighted repost to Substack (run on your Mac) and record it on prod"
    task tick: :environment do
      BlizzardRepostTick.run(commit: true)
    end
  end
end

module BlizzardRepostTick
  module_function

  def run(commit:)
    result = Substack::Blizzard::RepostTicker.execute(
      base_url: ENV.fetch("BLIZZARD_PROD_URL", "https://mikeyclarke.co.nz"),
      username: ENV["BLIZZARD_ADMIN_USER"] || ComfortableMexicanSofa::AccessControl::AdminAuthentication.username,
      password: ENV["BLIZZARD_ADMIN_PASS"] || ComfortableMexicanSofa::AccessControl::AdminAuthentication.password,
      commit:   commit
    )

    result.posted.each do |p|
      puts "── #{commit ? 'POSTED' : 'would post'} ──"
      puts p["text"]
      puts "→ #{p['url']}" if p["url"]
    end
    result.skipped.each do |s|
      puts "── SKIPPED (#{s['reason']}) ──"
      puts s["text"]
    end
    result.failed.each do |f|
      puts "── FAILED: #{f['error']} ──"
      puts f["text"]
    end

    puts "\n#{commit ? 'Posted' : 'Dry run'}: #{result.posted.size}." \
         " Skipped: #{result.skipped.size}. Failed: #{result.failed.size}."
  end
end

module BlizzardBackfillRunner
  module_function

  def run(commit:)
    client = Substack::Client.new
    cats   = Comfy::Cms::Categorization.joins(:category)
      .where(comfy_cms_categories: { label: "Substack" }).order(:id)
    flagged = []

    failed = []

    cats.find_each do |cat|
      begin
        result = Substack::Blizzard::Backfiller.execute(categorization: cat, client: client, commit: commit)
      rescue => e
        puts "CAT #{cat.id} (post #{cat.categorized_id}): FAILED — #{e.message[0, 120]}"
        failed << cat.id
        next
      ensure
        sleep 1 # gentle pacing to stay under Substack's rate limit
      end

      notes = result.blizzard.sum { |e| e["notes"].size }
      puts "CAT #{cat.id} (post #{cat.categorized_id}): #{result.blizzard.size} text group(s), #{notes} note(s)"
      result.flags.each { |f| puts "  ! #{f}" }
      flagged << cat.id if result.flags.any?
    end

    puts "\n#{commit ? 'Committed' : 'Dry run'}. #{cats.count} Substack categorizations." \
         " Flagged: #{flagged.join(', ').presence || 'none'}." \
         " Failed (re-run to retry): #{failed.join(', ').presence || 'none'}."
  end
end

module BlizzardUrlAppender
  module_function

  def run(commit:)
    cats = Comfy::Cms::Categorization.joins(:category)
      .where(comfy_cms_categories: { label: "Substack" }).order(:id)
    appended = 0
    missing_url = []

    cats.find_each do |cat|
      if cat.url.blank?
        missing_url << cat.id if Array(cat.data["blizzard"]).any?
        next
      end

      changed = false
      Array(cat.data["blizzard"]).each do |entry|
        next if entry["body_json"].blank?

        new_bj = Substack::NoteParser.append_post_url(entry["body_json"], cat.url)
        next if new_bj == entry["body_json"]

        entry["body_json"] = new_bj
        entry["text"]      = Substack::NoteParser.plaintext(new_bj)
        appended += 1
        changed  = true
      end

      if changed && commit
        cat.data_will_change! # in-place jsonb mutation can dodge dirty-tracking
        cat.save!
      end
    end

    puts "#{commit ? 'Appended URL to' : 'Would append URL to'} #{appended} blizzard entr#{appended == 1 ? 'y' : 'ies'}."
    puts "Categorizations with blizzard but no canonical #url (skipped): #{missing_url.join(', ').presence || 'none'}."
  end
end

module BlizzardBodyJsonFiller
  module_function

  def run(commit:)
    cats = Comfy::Cms::Categorization.joins(:category)
      .where(comfy_cms_categories: { label: "Substack" })
    filled = 0

    cats.find_each do |cat|
      changed = false
      Array(cat.data["blizzard"]).each do |entry|
        next if entry["body_json"].present? || entry["text"].blank?

        bj = Substack::NoteParser.text_to_body_json(entry["text"])
        bj = Substack::NoteParser.append_post_url(bj, cat.url) if cat.url.present?
        entry["body_json"] = bj
        entry["text"]      = Substack::NoteParser.plaintext(bj)
        filled  += 1
        changed  = true
        puts "POST #{cat.categorized_id} (cat #{cat.id}): #{entry['text'].to_s[0, 60]}"
      end

      if changed && commit
        cat.data_will_change! # in-place jsonb mutation can dodge dirty-tracking
        cat.save!
      end
    end

    puts "\n#{commit ? 'Filled' : 'Would fill'} body_json for #{filled} entr#{filled == 1 ? 'y' : 'ies'} (plain text, no formatting)."
  end
end

def proof_body_json
  {
    "type"    => "doc",
    "attrs"   => { "schemaVersion" => "v1" },
    "content" => [
      { "type" => "paragraph", "content" => [
        { "type" => "text", "text" => "blizzard proof " },
        { "type" => "text", "text" => "bold",   "marks" => [{ "type" => "bold" }] },
        { "type" => "text", "text" => " " },
        { "type" => "text", "text" => "italic", "marks" => [{ "type" => "italic" }] },
        { "type" => "text", "text" => " " },
        { "type" => "text", "text" => "link",   "marks" => [{ "type" => "link", "attrs" => { "href" => "https://mikeyclarke.co.nz" } }] }
      ] }
    ]
  }
end

def collect_marks(node, acc = Set.new)
  return acc if node.blank?

  (node["marks"] || []).each { |m| acc << m["type"] }
  (node["content"] || []).each { |child| collect_marks(child, acc) }
  acc
end
