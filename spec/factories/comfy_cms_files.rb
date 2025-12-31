# frozen_string_literal: true

FactoryBot.define do
  factory :comfy_cms_file, class: 'Comfy::Cms::File' do
    site
    label { "Test File #{SecureRandom.hex(4)}" }

    transient do
      file { nil }
    end

    after(:build) do |cms_file, evaluator|
      cms_file.file = evaluator.file if evaluator.file
    end
  end
end
