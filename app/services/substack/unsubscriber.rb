# frozen_string_literal: true

# Unsubscribes the owner from one publication listed on Subscription Cleanup,
# then asks Substack whether it took (the endpoint is unofficial, so a 2xx
# alone isn't trusted) and drops the local row. Free subscriptions only: a paid
# membership has billing attached and is cancelled by hand in Substack.
module Substack
  class Unsubscriber
    class Error < StandardError; end

    def self.execute(subscription, client: Client.new)
      new(subscription, client).execute
    end

    def initialize(subscription, client)
      @subscription = subscription
      @client = client
    end

    def execute
      raise Error, "Paid subscription — cancel it in Substack" if @subscription.paid?
      raise Error, "No Substack subdomain recorded" if @subscription.publication_subdomain.blank?

      @client.unsubscribe(@subscription.publication_subdomain, @subscription.publication_id)
      raise Error, "Substack still lists you as subscribed" if still_subscribed?

      @subscription.destroy!
    end

    private

    def still_subscribed?
      state = @client.publication_subscription(@subscription.publication_subdomain)
      return false unless state.is_a?(Hash)

      state["is_subscribed"] == true || state["is_free_subscribed"] == true
    rescue Client::NotFound
      false
    end
  end
end
