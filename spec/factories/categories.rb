FactoryBot.define do
  factory :category, class: 'Comfy::Cms::Category' do
    label            { 'Whimsy' }
    categorized_type { 'Comfy::Blog::Post' }

    site
  end
end
