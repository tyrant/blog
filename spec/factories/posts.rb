FactoryBot.define do
  factory :post, class: 'Comfy::Blog::Post' do
    title { 'populated by after :build' }
    slug  { 'populated by after :build' }
    is_published { true }
    published_at { 
      Faker::Time.between(from: DateTime.now-1, to: DateTime.now+1)
    }

    site
    layout

    after :build do |post|
      sentence = Faker::Hipster.sentence
      post.title = sentence
      post.slug = sentence.parameterize
      post.fragments << build(:fragment)
    end
  end
end