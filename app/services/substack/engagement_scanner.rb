# frozen_string_literal: true

# Records who engaged with my Substack content into SubstackEngagement: walks
# every post in the publication archive (comments, likes, restacks) and every
# Note on my profile (likes, restacks, replies), skipping the per-piece reads
# when its counts show nobody else engaged. `since` limits the walk to content
# published from then on (nil: everything). Idempotent, so an interrupted scan
# can simply be re-run.
module Substack
  class EngagementScanner
    include ServiceInterface

    arguments client: nil, since: nil, progress: nil

    PACING = 0.5 # seconds between pieces
    MAX_PAGES = 1_000

    def execute
      @client ||= Client.new
      @me = SubstackSyncConfig.instance.author_id or raise Client::Error, "No Substack author id configured"

      posts = collect(:posts)
      notes = collect(:notes)
      @progress&.update!(total: posts.size + notes.size)

      failures = 0
      [[posts, :scan_post], [notes, :scan_note]].each do |pieces, scanner|
        pieces.each do |piece|
          send(scanner, piece)
        rescue Client::AuthError
          raise
        rescue Client::Error => e
          failures += 1
          Rails.logger.warn("[EngagementScanner] #{scanner} #{piece['id']}: #{e.message}")
        ensure
          @progress&.advance!(detail: "#{scanner == :scan_post ? 'post' : 'note'} #{piece['id']}")
          pause
        end
      end

      { posts: posts.size, notes: notes.size, failures: failures }
    end

    private

    # Posts from the archive; my own Notes (not my restacks) from my profile feed.
    def collect(kind)
      pieces = []
      cursor = nil
      MAX_PAGES.times do
        page = kind == :posts ? @client.archive_page(cursor) : @client.profile_feed(@me, cursor)
        batch = kind == :posts ? Array(page["posts"]) : Array(page["items"]).filter_map { |item| my_note(item) }
        dated = kind == :posts ? ->(post) { post["post_date"] } : ->(note) { note["date"] }

        pieces.concat(batch.select { |piece| recent?(dated.(piece)) })
        cursor = page["nextCursor"]
        # The feed can lead with a pinned item, so only stop once a whole page is old.
        break if cursor.blank? || (page_dates(kind, page).any? && page_dates(kind, page).none? { |date| recent?(date) })
      end
      pieces.uniq { |piece| piece["id"] }
    end

    def page_dates(kind, page)
      kind == :posts ? Array(page["posts"]).map { |p| p["post_date"] } : Array(page["items"]).map { |i| i.dig("context", "timestamp") }.compact
    end

    def my_note(item)
      comment = item["comment"]
      comment if item["type"] == "comment" && item.dig("context", "type") == "note" && comment && comment["user_id"] == @me
    end

    def recent?(date)
      @since.nil? || date.blank? || Time.zone.parse(date.to_s) >= @since
    end

    def scan_post(post)
      key = "p-#{post['id']}"
      rows = []
      if post["comment_count"].to_i.positive?
        each_comment(@client.post_comments(post["id"])["comments"]) do |comment|
          rows << row(comment["user_id"], key, "comment", comment["date"], handle: comment["handle"], name: comment["name"])
        end
      end
      rows.concat(people(@client.post_reactors(post["id"]), key, "like", post["post_date"])) if others_liked?(post)
      rows.concat(people(@client.post_restackers(post["id"]), key, "restack", post["post_date"])) if post["restacks"].to_i.positive?
      SubstackEngagement.record!(rows.compact)
    end

    def scan_note(note)
      key = "c-#{note['id']}"
      rows = []
      rows.concat(people(@client.note_reactors(note["id"]), key, "like", note["date"])) if others_liked?(note)
      rows.concat(people(@client.note_restackers(note["id"]), key, "restack", note["date"])) if note["restacks"].to_i.positive?
      each_reply(note["id"]) { |reply| rows << row(reply["user_id"], key, "reply", reply["date"], handle: reply["handle"], name: reply["name"]) } if note["children_count"].to_i.positive?
      SubstackEngagement.record!(rows.compact)
    end

    # reaction_count includes my own like, if I gave one.
    def others_liked?(piece)
      piece["reaction_count"].to_i - (piece["reaction"].present? ? 1 : 0) > 0
    end

    def each_comment(comments, &block)
      Array(comments).each do |comment|
        yield comment unless comment["deleted"]
        each_comment(comment["children"], &block)
      end
    end

    def each_reply(note_id)
      cursor = nil
      MAX_PAGES.times do
        page = @client.note_replies(note_id, cursor)
        Array(page["commentBranches"]).each do |branch|
          [branch["comment"], *Array(branch["descendantComments"]).map { |d| d["comment"] || d }].compact.each { |reply| yield reply }
        end
        cursor = page["nextCursor"]
        break if cursor.blank?
      end
    end

    def people(list, key, kind, date)
      Array(list).map { |person| row(person["id"], key, kind, date, handle: person["handle"], name: person["name"]) }
    end

    def row(user_id, key, kind, date, handle: nil, name: nil)
      return if user_id.blank? || user_id == @me

      { user_id: user_id, handle: handle.presence, name: name.presence, content_key: key, kind: kind,
        occurred_at: date.present? ? Time.zone.parse(date.to_s) : nil }
    end

    def pause
      sleep PACING
    end
  end
end
