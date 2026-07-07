# frozen_string_literal: true

# Refreshes the stored "likes" count on every note of one Substack categorization
# by re-fetching each note and reading its reaction_count. Reads are allowed from
# the prod IP, so this runs on the prod worker. Idempotent (overwrites likes).
#
# A note that no longer fetches (deleted, transient error) keeps its last-known
# likes rather than being zeroed.
module Substack
  module Blizzard
    class LikesRefresher
      include ServiceInterface

      arguments :categorization, client: nil, commit: true

      Result = Struct.new(:updated, :failed, keyword_init: true)

      def execute
        @client ||= Substack::Client.new
        data    = @categorization.data
        updated = 0
        failed  = 0

        Array(data["blizzard"]).each do |entry|
          Array(entry["notes"]).each do |note|
            comment_id = NoteParser.comment_id_from_url(note["url"])
            next if comment_id.nil?

            begin
              comment = NoteParser.comment(@client.get_note(comment_id))
              note["likes"] = NoteParser.likes(comment)
              updated += 1
            rescue Substack::Client::Error => e
              failed += 1
              Rails.logger.warn("[LikesRefresher] cat #{@categorization.id} note c-#{comment_id}: #{e.message}")
            end
          end
        end

        if @commit && updated.positive?
          @categorization.data_will_change! # in-place jsonb mutation can dodge dirty-tracking
          @categorization.save!
        end

        Result.new(updated: updated, failed: failed)
      end
    end
  end
end
