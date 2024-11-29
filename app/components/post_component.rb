class PostComponent < ViewComponent::Base

  # Remember, we can't just slap on any old number, Tailwind has preset defaults:
  # https://tailwindcss.com/docs/transition-duration
  DURATION = 150

  CAT_COMMON_CSS = %w(hover:outline rounded)

  CAT_UNIQUE_CSS = {
    'all-posts'    => %w(bg-gray-100),
    'whimsy'       => %w(bg-indigo-100 text-indigo-800 outline-indigo-800),
    'nsfw'         => %w(bg-red-800 text-red-100 outline-red-100),
    'shite-advice' => %w(bg-lime-100 text-lime-800 outline-lime-800)
  }

  POST_CAT_CSS = {
    'whimsy'       => %w(cat-blurrable),
    'nsfw'         => %w(),
    'shite-advice' => %w(cat-blurrable)
  }

  def initialize(post:, cms_site:, nsfw_options:)
    @post = post
    @cms_site = cms_site
    @nsfw_options = nsfw_options
  end

  private

  def post_title
    @post.title.truncate 72, separator: ' ', omission: ' ...'
  end

  def post_link
    comfy_blog_post_path(@cms_site.path, @post.year, @post.month, @post.slug)
  end

  def post_image_path
    @cached_post_image_path ||= @post.resized_blob_or_orig_or_placeholder_url
  end

  def post_content
    @cached_post_content ||= begin 
        html_content = @post
          .content_cache
          .gsub('</h2>', "</h2>\r\n")
          .gsub('</p>', "</p>\r\n")
        Nokogiri::HTML(html_content)
          .text
          .truncate(120, separator: ' ', omission: ' ...')
      end
  end

  def css_classes
    classes = %w(post transition bg-white p-3 rounded-xl shadow-lg) << "duration-#{DURATION}"
    classes += %w(hidden opacity-0) if @post.nsfw? && @nsfw_options['banish']

    classes.join ' '
  end

  def css_classes_for_body
    classes = %w(relative link transition) << "duration-#{DURATION}"
    
    if @post.nsfw? && !(@nsfw_options['mouseover'] && @nsfw_options['always'])
      classes += %w(blur-sm)
    end

    classes.join ' '
  end

  def css_classes_for_category(category)
    label = category.label.parameterize

    classes = %w(inline-block text-xs font-medium mb-2 px-2.5 py-1 float-right clear-both opacity-90 transition) << CAT_COMMON_CSS << CAT_UNIQUE_CSS[label] << POST_CAT_CSS[label] << "duration-#{DURATION}"
    
    if (@post.nsfw? && label != 'nsfw') && !@nsfw_options['always']
      classes += %w(blur-sm)
    end 

    classes.join ' '
  end

  def css_classes_for_datebg
    classes = %w(absolute h-64 w-full top-0 left-0 z-10 transition)

    if @post.nsfw? && !(@nsfw_options['mouseover'] && @nsfw_options['always'])
      classes += %w(blur-sm)
    end

    classes.join ' '
  end
end
