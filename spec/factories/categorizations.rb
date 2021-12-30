FactoryBot.define do
  factory :categorization, class: 'Comfy::Cms::Categorization' do
    category
    association :categorized, factory: :post
  end
end