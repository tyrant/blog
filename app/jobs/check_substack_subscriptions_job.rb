# frozen_string_literal: true

# Saves per row, so re-running after an interruption resumes rather than restarts.
class CheckSubstackSubscriptionsJob < ApplicationJob
  include JobProgressReporting

  queue_as :default

  PACING = 1 # second between profiles

  def perform(recheck: false)
    SubstackSubscription.update_all(checked_at: nil) if recheck
    pending = SubstackSubscription.unchecked
    client = Substack::Client.new

    with_progress("check_substack_subscriptions", label: "Check subscription follow-backs", total: pending.count) do |progress|
      pending.find_each do |subscription|
        Substack::SubscriptionChecker.execute(subscription, client: client)
        progress.advance!(detail: subscription.publication_name)
        sleep PACING
      end
    end
  end
end
