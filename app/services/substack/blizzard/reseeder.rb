# frozen_string_literal: true

# Replaces a blizzard entry's canonical body_json by reading a real Substack Note
# (lossless: the note's ProseMirror marks — bold/italic/links — come back intact).
# Used to upgrade entries whose body_json is plain (generated from text) to rich.
# Reading is allowed from the prod IP; only writes are Cloudflare-blocked.
#
# Touches only body_json + text; the entry's notes (repost history) are left alone.
module Substack
  module Blizzard
    class Reseeder
      include ServiceInterface

      arguments :categorization, :uid, :note_url, client: nil

      def execute
        @client ||= Substack::Client.new
        entry = Array(@categorization.data["blizzard"]).find { |e| e["uid"] == @uid }
        raise ArgumentError, "No blizzard entry #{@uid}" if entry.nil?

        comment_id = NoteParser.comment_id_from_url(@note_url)
        raise ArgumentError, "Not a Substack note URL" if comment_id.nil?

        comment   = NoteParser.comment(@client.get_note(comment_id))
        body_json = NoteParser.body_json(comment)
        raise "That note has no readable body" if body_json.blank?

        body_json = NoteParser.append_post_url(body_json, @categorization.url) if @categorization.url.present?
        entry["body_json"] = body_json
        entry["text"]      = NoteParser.plaintext(body_json)

        @categorization.data_will_change! # in-place jsonb mutation can dodge dirty-tracking
        @categorization.save!
        entry
      end
    end
  end
end
