def build_content
  <<~HEREDOC
    #{Faker::Boolean.boolean(true_ratio: 0.7) ? "<p><img src='http://picsum.photos/#{Faker::Number.between(from: 300, to: 600)}/#{Faker::Number.between(from: 200, to: 450)}/' /></p>" : ""}
    #{(2..8).map { "<p>#{Faker::Lorem.paragraph(sentence_count: Faker::Number.between(from: 1, to: 20))}</p>" }.join}
  HEREDOC
end


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
}, {
  site: site,
  label: 'NSFW',
  categorized_type: 'Comfy::Blog::Post'
}])

50.times do |n|
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
        content: build_content,
      }
    }
  )

  # Those maniacs overwrite #published_at :O 
  # https://github.com/comfy/comfy-blog/blob/93c874fe928ed2fa5d8785e47aa6cf216aeb14f3/app/models/comfy/blog/post.rb#L51
  # Can't have that. We'll have to update it the old-fashioned way.
  post.published_at = Time.now + n.weeks
  post.save!(validate: false)

  # For each post, create random categorisations: 0-3. Some posts will have
  # zero categories; others 1, or 2, or 3.
  rand_count = rand(Comfy::Cms::Category.count + 1)
  categorizations = Comfy::Cms::Category.limit(rand_count)
    .order('RANDOM()').map do |category|
      { 
        category: category,
        categorized: post
      }
    end
    
  Comfy::Cms::Categorization.create!(categorizations)
end
