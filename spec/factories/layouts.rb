FactoryBot.define do
  factory :layout, class: 'Comfy::Cms::Layout' do
    label      { 'default' }
    identifier { 'default' }
    app_layout { 'application' }
    content    { '{{ cms:wysiwyg content }}' }

    site
  end
end