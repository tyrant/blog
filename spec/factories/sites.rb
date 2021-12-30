FactoryBot.define do
  factory :site, class: 'Comfy::Cms::Site' do
    label      { "blog-#{Faker::Internet.uuid}" }
    identifier { "blog-#{Faker::Internet.uuid}" }
    hostname   { "localhost-#{Faker::Internet.uuid}" }
  end
end