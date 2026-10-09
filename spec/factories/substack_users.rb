# frozen_string_literal: true

FactoryBot.define do
  factory :substack_user do
    sequence(:user_id) { |n| 1000 + n }
    sequence(:handle) { |n| "reader#{n}" }
    name { 'Reader' }

    # Handles are unique, so specs naming the same one share a row.
    initialize_with { handle ? SubstackUser.find_or_initialize_by(handle: handle) : new }
  end
end
