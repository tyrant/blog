class PostComponent < ViewComponent::Base

  # Remember, we can't just slap on any old number, Tailwind has preset defaults:
  # https://tailwindcss.com/docs/transition-duration
  DURATION = 150

  CAT_COMMON_CSS = %w(hover:outline rounded)

  CAT_UNIQUE_CSS = {
    'all-posts'    => %w(bg-gray-100 text-gray-900 dark:text-gray-900),
    'whimsy'       => %w(bg-indigo-100 text-indigo-800 outline-indigo-800),
    'nsfw'         => %w(bg-red-800 text-red-100 outline-red-100),
    'shite-advice' => %w(bg-lime-100 text-lime-800 outline-lime-800)
  }

  POST_CAT_CSS = {
    'whimsy'       => %w(cat-blurrable),
    'nsfw'         => %w(),
    'shite-advice' => %w(cat-blurrable)
  }

  def initialize(post:, cms_site:, nsfw_options:, show_text: true)
    @post = post
    @cms_site = cms_site
    @nsfw_options = nsfw_options
    @show_text = show_text
  end

  private

  def post_title
    @post_title ||= @post.title.truncate 72, separator: ' ', omission: ' ...'
  end

  def css_classes_for_title
    classes = %w(absolute w-full p-5 bottom-0 left-0
                 font-['Racing_Sans_One']
                 text-center text-gray-100 text-outlined)
                 
    len = post_title.length
    if len <= 30
      classes << "text-xl md:text-2xl leading-[1.1rem] sm:leading-[1.3rem] md:leading-[1.4rem]"
    elsif len <= 55
      classes << "text-lg md:text-xl leading-[1.05rem] sm:leading-[1.2rem] md:leading-[1.3rem]"
    else
      classes << "text-base md:text-lg leading-[1.0rem] sm:leading-[1.1rem] md:leading-[1.2rem]"
    end
    
    classes.join ' '
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
        Nokogiri::HTML(html_content).text.truncate(240, separator: ' ', omission: ' ...')
      end
  end

  def css_classes
    classes = %w(post transition bg-white dark:bg-gray-800 rounded-xl shadow-lg) << "duration-#{DURATION}"
    classes += %w(hidden opacity-0) if @post.nsfw? && @nsfw_options['banish']

    classes.join ' '
  end

  def css_classes_for_body
    classes = %w(link transition) << "duration-#{DURATION}"
    
    if @post.nsfw? && !(@nsfw_options['mouseover'] && @nsfw_options['always'])
      classes += %w(blur-xs)
    end

    classes.join ' '
  end

  def css_classes_for_category(category)
    label = category.label.parameterize

    classes = %w(inline-block text-xs font-medium mb-2 px-2.5 py-1 float-right clear-both opacity-90 transition) << CAT_COMMON_CSS << CAT_UNIQUE_CSS[label] << POST_CAT_CSS[label] << "duration-#{DURATION}"
    
    if (@post.nsfw? && label != 'nsfw') && !@nsfw_options['always']
      classes += %w(blur-xs)
    end 

    classes.join ' '
  end

  def css_classes_for_datebg
    classes = %w(absolute h-64 w-full top-0 left-0 z-10 transition)

    if @post.nsfw? && !(@nsfw_options['mouseover'] && @nsfw_options['always'])
      classes += %w(blur-xs)
    end

    classes.join ' '
  end

  def css_classes_for_image
    classes = %w(object-cover w-full h-64 shadow-lg scale-100 ease-in duration-150)
    classes += @show_text ? %w(rounded-t-xl) : %w(rounded-xl)
    classes.join ' '
  end

  def css_classes_for_titlebg
    classes = %w(w-full h-28 bg-gradient-to-b from-transparent to-60% to-neutral-800/75 absolute top-36 left-0)
    classes += @show_text ? %w() : %w(rounded-b-xl) 
    classes.join ' '
  end
end
