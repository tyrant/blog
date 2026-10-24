# frozen_string_literal: true

module Substack
  # Mirrors the owner's Substack subscriptions (minus their own publication) into SubstackSubscription.
  class SubscriptionImporter
    MAX_PAGES = 100 # ~200 per page, comfortably past the 5,000 cap
    PACING = 0.5    # seconds between pages

    def self.execute(client: Client.new, owner_id: SubstackSyncConfig.instance.author_id)
      new(client: client, owner_id: owner_id).execute
    end

    def initialize(client:, owner_id:)
      @client = client
      @owner_id = owner_id
    end

    def execute
      seen = []
      cursor = nil

      MAX_PAGES.times do
        page = @client.subscriptions_page(cursor)
        publications = Array(page["publications"]).index_by { |publication| publication["id"] }

        Array(page["subscriptions"]).each do |subscription|
          publication = publications[subscription["publication_id"]] || {}
          next if @owner_id.present? && publication["author_id"] == @owner_id

          upsert(subscription, publication)
          seen << subscription["id"]
        end

        cursor = page["nextCursor"]
        break if cursor.blank?

        sleep PACING
      end

      # An empty list is far likelier a bad response than zero subscriptions.
      SubstackSubscription.where.not(subscription_id: seen).delete_all if seen.any?
      seen.size
    end

    private

    def upsert(subscription, publication)
      record = SubstackSubscription.find_or_initialize_by(subscription_id: subscription["id"])
      record.assign_attributes(
        publication_id:            subscription["publication_id"],
        publication_name:          publication["name"],
        publication_subdomain:     publication["subdomain"],
        publication_custom_domain: publication["custom_domain"],
        author_id:                 publication["author_id"],
        membership_state:          subscription["membership_state"],
        subscribed_at:             subscription["created_at"]
      )
      if record.persisted? && record.author_id_changed?
        record.assign_attributes(author_handle: nil, author_name: nil, follows_me: nil, subscribes_to_me: nil,
                                 author_follower_count: nil, checked_at: nil, check_error: nil)
      end
      record.save!
    end
  end
end
