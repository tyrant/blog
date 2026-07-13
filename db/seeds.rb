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

# Topical categories (Whimsy/NSFW/Shite Advice) are now Tags, not Categories.
cats = ['Medium', 'Substack', 'Twitter', 'LinkedIn', 'FB'].each do |label|
  Comfy::Cms::Category.create!(
    site: site,
    categorized_type: 'Comfy::Blog::Post',
    label: label
  )
end


50.times do |n|
  sentence = Faker::Lorem.sentence(word_count: rand(3..30))
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
  
  # Add a sprinkling of posts for the previous 200 weeks, ~4 years.
  post.published_at = Time.now - (4*n).weeks
  post.save!(validate: false)

  # For each post, create random categorisations: 0-Category.count. Some posts will have
  # zero categories; others more.
  rand_count = rand(Comfy::Cms::Category.count + 1)
  categorizations = Comfy::Cms::Category.limit(rand_count)
    .order('RANDOM()').map do |category|
      { 
        category: category,
        categorized: post
      }
    end
    
  Comfy::Cms::Categorization.create!(categorizations)

  # Ensure each Post#scratchpad contains socials-URLs relevant to its socials-categories.
  # I maintain these myself manually, remember.
  scratchpad = []
  socials = [{ label: 'Medium', url: 'https://medium.com/@pi_neutrino' },
             { label: 'Substack', url: 'https://pi-neutrino.substack.com/' },
             { label: 'Twitter', url: 'https://twitter.com/pi_neutrino' },
             { label: 'LinkedIn', url: 'https://linkedin.com/in/pi_neutrino' },
             { label: 'FB', url: 'https://facebook.com/pi_neutrino' }]

  socials.each do |social|
    if post.categories.any?{|c| c.label == social[:label] }
      scratchpad << social[:url]
    end
  end

  # Calling `post.save(validate: false)` wipes the Post's category list. No idea why.
  # I'm too harrumphy and impatient to get to the bottom of it, bah and dagnabbit.`
  post.update_column :scratchpad, scratchpad.join("\r\n\r\n")
end
