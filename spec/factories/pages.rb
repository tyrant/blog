FactoryBot.define do
  factory :page, class: 'Comfy::Cms::Page' do
    label       { "Page #{Faker::Internet.uuid}" }
    slug        { Faker::Internet.slug }
    full_path   { "/#{slug}" }
    is_published { true }

    site
    layout
  end
end
