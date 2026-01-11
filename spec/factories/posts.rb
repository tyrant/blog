FactoryBot.define do
  factory :post, class: 'Comfy::Blog::Post' do
    transient do
      custom_title { nil }
      custom_slug { nil }
    end

    placeholder_title = 'populated by after :build'
    title { placeholder_title }
    slug  { placeholder_title }

    is_published { true }
    published_at { Faker::Time.between(from: DateTime.now - 1, to: DateTime.now + 1) }

    site
    layout

    # We populate #title and #slug here so's we can use the same Faker sentence
    # for both attributes.
    after :build do |post, evaluator|
      sentence = Faker::Hipster.sentence

      # Only populate if the attribute is still the placeholder value - a spec
      # may have already set its own custom value.
      post.title = evaluator.custom_title || sentence if post.title == placeholder_title
      post.slug = evaluator.custom_slug || sentence.parameterize if post.slug == placeholder_title
    end
  end
end