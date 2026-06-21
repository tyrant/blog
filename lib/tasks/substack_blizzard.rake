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
