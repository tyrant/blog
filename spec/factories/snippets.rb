FactoryBot.define do
  factory :snippet, class: 'Comfy::Cms::Snippet' do
    label      { "Snippet #{Faker::Internet.uuid}" }
    identifier { "snippet-#{Faker::Internet.uuid}" }
    content    { '<p>Snippet content</p>' }

    site
  end
end
