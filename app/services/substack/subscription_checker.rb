# frozen_string_literal: true

module Substack
  # A dead session raises so the whole run stops; any other failure is recorded on the row.
  class SubscriptionChecker
    def self.execute(subscription, client: Client.new, owner_id: SubstackSyncConfig.instance.author_id)
      new(subscription, client: client, owner_id: owner_id).execute
    end

    def initialize(subscription, client:, owner_id:)
      @subscription = subscription
      @client = client
      @owner_id = owner_id
    end

    def execute
      profile = fetch_profile
      @subscription.update!(
        author_handle:         profile["handle"],
        author_name:           profile["name"],
        follows_me:            profile["followsViewer"] == true,
        subscribes_to_me:      subscribes_to_owner?(profile),
        author_follower_count: profile["followerCount"],
        checked_at:            Time.current,
        check_error:           nil
      )
    rescue Client::AuthError
      raise
    rescue Client::Error => e
      @subscription.update!(checked_at: Time.current, check_error: e.message.first(255))
    end

    private

    # The publication subdomain is usually the handle; the /profile/<id> redirect is the fallback.
    def fetch_profile
      guess = @subscription.author_handle.presence || @subscription.publication_subdomain
      @client.public_profile(@subscription.author_id, guess)
    rescue Client::NotFound
      handle = @client.handle_for(@subscription.author_id)
      raise Client::NotFound, "No Substack profile found for user #{@subscription.author_id}" if handle.blank? || handle == guess

      @client.public_profile(@subscription.author_id, handle)
    end

    # Private subscriptions aren't listed, but those subscribers nearly always follow too.
    def subscribes_to_owner?(profile)
      return false if @owner_id.blank?

      Array(profile["subscriptions"]).any? { |subscription| subscription.dig("publication", "author_id") == @owner_id }
    end
  end
end
