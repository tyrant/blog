# frozen_string_literal: true

class ImportSubstackSubscriptionsJob < ApplicationJob
  queue_as :default

  def perform
    Substack::SubscriptionImporter.execute
    CheckSubstackSubscriptionsJob.perform_later
  end
end
