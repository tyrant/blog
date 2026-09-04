# frozen_string_literal: true

# Populates a record's data["blizzard"] from its existing data["notes"] URLs:
# fetches each note, extracts rich body_json + plaintext + timestamp, and groups
# notes that share the same text into blizzard entries. `categorization` is either
# a Substack Comfy::Cms::Categorization or the BlizzardScheduleConfig singleton
# (the unattached-notes pool) — both expose #data/#update!(data:); only the
# categorization has #url, so the mislink check below no-ops for the latter.
#
# Additive and idempotent: data["notes"] is never touched, and a note already
# recorded under any blizzard entry is skipped on re-runs.
module Substack
  module Blizzard
    class Backfiller
      include ServiceInterface

      arguments :categorization, client: nil, commit: true

      Result = Struct.new(:blizzard, :flags, keyword_init: true)

      def execute
        @client ||= Substack::Client.new
        data     = @categorization.data
        blizzard = (data["blizzard"] ||= [])
        flags    = []

        note_urls(data).each do |note_url|
          comment_id = NoteParser.comment_id_from_url(note_url)
          next if comment_id.nil? || already_recorded?(blizzard, note_url)

          comment   = NoteParser.comment(@client.get_note(comment_id))
          body_json = NoteParser.body_json(comment)
          text      = NoteParser.plaintext(body_json)
          record    = { "url" => note_url, "timestamp" => NoteParser.timestamp(comment) }

          flags << wrong_url_flag(note_url, body_json) if mislinked?(body_json)

          if (entry = match(blizzard, text))
            entry["notes"] << record
          else
            blizzard << { "uid" => SecureRandom.uuid, "text" => text, "body_json" => body_json, "notes" => [record] }
          end
        end

        @categorization.update!(data: data) if @commit
        Result.new(blizzard: blizzard, flags: flags)
      end

      private

      def note_urls(data)
        Array(data["notes"]).select { |u| u.is_a?(String) }
      end

      def already_recorded?(blizzard, note_url)
        blizzard.any? { |entry| entry["notes"].any? { |n| n["url"] == note_url } }
      end

      def match(blizzard, text)
        key = NoteParser.normalize(text)
        blizzard.find { |entry| NoteParser.normalize(entry["text"]) == key }
      end

      # A note should link to this categorization's canonical post (#url). Flag
      # when the note links to some post but none matches — likely a stray URL.
      def mislinked?(body_json)
        canonical = NoteParser.post_slug(@categorization.try(:url))
        return false if canonical.blank?

        slugs = NoteParser.link_hrefs(body_json).map { |h| NoteParser.post_slug(h) }.compact
        slugs.any? && slugs.none?(canonical)
      end

      def wrong_url_flag(note_url, body_json)
        linked = NoteParser.link_hrefs(body_json).map { |h| NoteParser.post_slug(h) }.compact.uniq
        "#{note_url} links to post(s) #{linked.join(', ')}, not #{NoteParser.post_slug(@categorization.url)}"
      end
    end
  end
end
