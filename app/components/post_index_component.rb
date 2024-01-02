class PostIndexComponent < ViewComponent::Base

  # Remember, we can't just slap on any old number, Tailwind has preset defaults:
  # https://tailwindcss.com/docs/transition-duration
  DURATION = 150

  CAT_COMMON_CSS = %w(hover:outline rounded)
  CAT_UNIQUE_CSS = {
    'all-posts' => %w(bg-gray-100),
    'whimsy' => %w(bg-indigo-100 text-indigo-800 outline-indigo-800),
    'nsfw' => %w(bg-red-800 text-red-100 outline-red-100),
    'shite-advice' => %w(bg-lime-100 text-lime-800 outline-lime-800)
  }

  POST_INDEX_CAT_CSS = {
    'whimsy' => %w(cat-blurrable),
    'nsfw' => %w(),
    'shite-advice' => %w(cat-blurrable)
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
    classes = %w(relative link transition) << "duration-#{DURATION}"
    
    if @post.nsfw? && !(@nsfw_options['mouseover'] && @nsfw_options['always'])
      classes += %w(blur-sm)
    end

    classes.join ' '
  end

  def css_classes_for_category(category)
    label = category.label.parameterize

    classes = %w(inline-block text-xs font-medium mb-2 px-2.5 py-1 float-right clear-both opacity-90 transition) << CAT_COMMON_CSS << CAT_UNIQUE_CSS[label] << POST_INDEX_CAT_CSS[label] << "duration-#{DURATION}"
    
    if (@post.nsfw? && label != 'nsfw') && !@nsfw_options['always']
      classes += %w(blur-sm)
    end 

    classes.join ' '
  end
end
