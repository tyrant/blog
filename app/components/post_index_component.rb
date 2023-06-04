class PostIndexComponent < ViewComponent::Base

  # Remember, we can't just slap on any old number, Tailwind has preset defaults:
  # https://tailwindcss.com/docs/transition-duration
  DURATION = 150

  CAT_CSS = {
    'whimsy' => %w(cat-blurrable bg-indigo-100 text-indigo-800 outline-indigo-800),
    'nsfw' => %w(bg-red-800 text-red-100 outline-red-100),
    'very-bad-advice' => %w(cat-blurrable bg-lime-100 text-lime-800 outline-lime-800)
  }

  def initialize(post_index:, cms_site:, nsfw_options:)
    @post = post_index
    @cms_site = cms_site
    @nsfw_options = nsfw_options
  end

  private

  def css_classes
    classes = %w(post-index relative transition) << "duration-#{DURATION}"
    classes += %w(hidden opacity-0) if @post.nsfw? && @nsfw_options['banish']

    classes.join ' '
  end

  def css_classes_for_link
    classes = %w(link transition) << "duration-#{DURATION}"
    
    if @post.nsfw? && !(@nsfw_options['mouseover'] && @nsfw_options['always'])
      classes += %w(blur-sm)
    end

    classes.join ' '
  end

  def css_classes_for_category(category)
    label = category.label.parameterize

    classes = %w(inline-block text-xs hover:outline font-medium mb-2 px-2.5 py-1 rounded float-right clear-both opacity-90 transition) << CAT_CSS[label] << "duration-#{DURATION}"
    
    if (@post.nsfw? && label != 'nsfw') && !@nsfw_options['always']
      classes += %w(blur-sm)
    end 

    classes.join ' '
  end
end
