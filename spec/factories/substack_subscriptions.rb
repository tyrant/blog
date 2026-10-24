# frozen_string_literal: true

FactoryBot.define do
  factory :substack_subscription do
    sequence(:subscription_id) { |n| 5000 + n }
    sequence(:publication_id) { |n| 7000 + n }
    sequence(:publication_subdomain) { |n| "writer#{n}" }
    publication_name { 'A Publication' }
    sequence(:author_id) { |n| 9000 + n }
    membership_state { 'free_signup' }
    subscribed_at { 1.month.ago }

    trait :checked do
      follows_me { false }
      subscribes_to_me { false }
      checked_at { 1.day.ago }
    end
  end
end
