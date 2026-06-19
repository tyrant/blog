# frozen_string_literal: true

# Reposts a single blizzard text-group as a fresh Substack Note (lossless, from
# the stored body_json), then appends {url, timestamp} to that group's notes.
# Used by the admin "Create note now" action and by any cron over DueFinder.
module Substack
  module Blizzard
    class Reposter
      include ServiceInterface

      arguments :categorization, :entry_index, client: nil, commit: true

      def execute
        @client ||= Substack::Client.new
        entry     = @categorization.data.dig("blizzard", @entry_index)
        raise ArgumentError, "No blizzard entry #{@entry_index}" if entry.nil?

        created = NoteParser.comment(@client.create_note(entry["body_json"]))
        record  = {
          "url"       => note_url(entry, created["id"]),
          "timestamp" => NoteParser.timestamp(created) || Time.current.utc.iso8601
        }

        entry["notes"] << record
        @categorization.update!(data: @categorization.data) if @commit
        record
      end

      private

      # New notes live on the same profile as the group's existing notes, so reuse
      # an existing note URL and swap its comment id. Falls back to a bare URL.
      def note_url(entry, new_id)
        template = Array(entry["notes"]).map { |n| n["url"] }.compact.first
        old_id   = template && NoteParser.comment_id_from_url(template)
        return template.sub("c-#{old_id}", "c-#{new_id}") if old_id

        "https://substack.com/note/c-#{new_id}"
      end
    end
  end
end
