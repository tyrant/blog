if !(Rails.env.development? || Rails.env.test?)
  puts "Are you nuts? We're in the #{Rails.env} env! `rake db:seed` will wipe the entire database! You're a numpty. Exiting now."
  exit
end


Comfy::Cms::Site.destroy_all
Comfy::Cms::Layout.destroy_all
Comfy::Cms::Categorization.destroy_all
Comfy::Cms::Category.destroy_all
Comfy::Cms::Fragment.destroy_all
Comfy::Blog::Post.destroy_all

site = Comfy::Cms::Site.create!(
  label: 'blog',
  identifier: 'blog',
  hostname: 'localhost'
)
layout = Comfy::Cms::Layout.create!(
  site: site,
  label: 'default',
  identifier: 'default',
  app_layout: 'application',
  content: '{{ cms:wysiwyg content }}'
)
cats = Comfy::Cms::Category.create!([{
  site: site,
  label: 'Very Bad Advice',
  categorized_type: 'Comfy::Blog::Post'
}, {
  site: site,
  label: 'Whimsy',
  categorized_type: 'Comfy::Blog::Post'
}])

50.times do 
  sentence = Faker::Hipster.sentence
  post = Comfy::Blog::Post.create!(
    site: site,
    layout: layout,
    title: sentence,
    slug: sentence.parameterize,
    fragments_attributes: {
      '0': {
        identifier: :content, 
        tag: "wysiwyg",
        content: "<p>#{Faker::Lorem.paragraph(sentence_count: 17)}</p><p>#{Faker::Lorem.paragraph(sentence_count: 17)}</p><p>#{Faker::Lorem.paragraph(sentence_count: 17)}</p><p><img src='http://lorempixel.com/#{Faker::Number.between(from: 300, to: 600)}/#{Faker::Number.between(from: 200, to: 450)}/'></p><p>#{Faker::Lorem.paragraph(sentence_count: 17)}</p><p>#{Faker::Lorem.paragraph(sentence_count: 17)}</p><p>#{Faker::Lorem.paragraph(sentence_count: 17)}</p>"
      }
    }
  )

  categorized = Comfy::Cms::Categorization.create!(
    category: cats.sample,
    categorized: post
  )
end