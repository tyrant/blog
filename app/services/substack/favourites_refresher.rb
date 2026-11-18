# frozen_string_literal: true

# Pulls each favourite SubstackUser's recent posts and Notes (the first page of
# their profile feed — not their restacks) into SubstackFavouriteItem, for the
# Substack Favourites feed. A favourite known only by handle gets its numeric
# id looked up first. Refreshes liked/restacked on items already listed, never
# touches "Done", and prunes items too old to bother replying to.
module Substack
  class FavouritesRefresher
    include ServiceInterface

    arguments client: nil, progress: nil

    MAX_AGE = 30.days
    PRUNE_AFTER = 60.days
    PACING = 1 # second between favourites

    def execute
      @client ||= Client.new
      favourites = SubstackUser.favourites.order(:id).to_a
      @progress&.update!(total: favourites.size)

      added = 0
      failures = []
      favourites.each do |user|
        added += refresh(user)
      rescue Client::AuthError
        raise
      rescue Client::Error => e
        failures << "#{user.handle || user.name}: #{e.message}"
        Rails.logger.warn("[FavouritesRefresher] #{user.id}: #{e.message}")
      ensure
        @progress&.advance!(detail: user.handle || user.name)
        pause
      end

      SubstackFavouriteItem.where(published_at: ...PRUNE_AFTER.ago).delete_all
      { added: added, failures: failures }
    end

    private

    def refresh(user)
      user = with_user_id(user) or return 0
      Array(@client.profile_feed(user.user_id)["items"]).count do |item|
        attrs = item_attrs(item, user) or next false
        next false if attrs[:published_at] < MAX_AGE.ago

        record = SubstackFavouriteItem.find_or_initialize_by(entity_key: attrs.delete(:entity_key))
        created = record.new_record?
        record.update!(attrs.merge(substack_user: user))
        created
      end
    end

    def with_user_id(user)
      return user if user.user_id
      return nil if user.handle.blank?

      profile = @client.public_profile_by_handle(user.handle)
      SubstackUser.identify(user_id: profile["id"], handle: profile["handle"].presence || user.handle,
                            name: user.name.presence || profile["name"])
    end

    def item_attrs(item, user)
      context = item.dig("context", "type").to_s
      return nil if context.end_with?("restack")

      if item["type"] == "comment" && (note = item["comment"]) && note["user_id"] == user.user_id
        note_attrs(note, user)
      elsif item["type"] == "post" && (post = item["post"]) && Array(post["publishedBylines"]).any? { |b| b["id"] == user.user_id }
        post_attrs(post)
      end
    end

    def note_attrs(note, user)
      handle = note["handle"].presence || user.handle
      url = handle ? "https://substack.com/@#{handle}/note/c-#{note['id']}" : "https://substack.com/profile/#{user.user_id}/note/c-#{note['id']}"
      { entity_key: "c-#{note['id']}", kind: "note", url: url, title: nil,
        excerpt: note["body"].to_s.squish.truncate(280), published_at: Time.zone.parse(note["date"].to_s),
        liked: note["reaction"].present?, restacked: note["restacked"] == true }
    end

    def post_attrs(post)
      { entity_key: "p-#{post['id']}", kind: "post", url: post["canonical_url"], title: post["title"],
        excerpt: (post["subtitle"].presence || post["description"]).to_s.squish.truncate(280),
        published_at: Time.zone.parse(post["post_date"].to_s),
        liked: post["reaction"].present?, restacked: post["restacked"] == true }
    end

    def pause
      sleep PACING
    end
  end
end
