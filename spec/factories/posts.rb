FactoryBot.define do
  factory :post, class: 'Comfy::Blog::Post' do
    transient do
      custom_title { nil }
      custom_slug { nil }
    end

    title { 'populated by after :build' }
    slug  { 'populated by after :build' }
    is_published { true }
    published_at { Faker::Time.between(from: DateTime.now - 1, to: DateTime.now + 1) }

    site
    layout

    after :build do |post, evaluator|
      sentence = Faker::Hipster.sentence
      post.title = evaluator.custom_title || sentence
      post.slug = evaluator.custom_slug || sentence.parameterize
      post.fragments << build(:fragment)
    end
  end
end