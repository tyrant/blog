class PrevNekComponent < ViewComponent::Base

  with_collection_parameter :category

  def initialize(category: nil, post:, site:, nsfw_options:)
    @category = category
    @post = post
    @site = site
    @nsfw_options = nsfw_options
  end

  def prev
    @cached_prev ||= @post.prev tag: @category, nsfw: !@nsfw_options['banish']
  end

  def nek
    @cached_nek ||= @post.nek tag: @category, nsfw: !@nsfw_options['banish']
  end

  def prev_thumb_or_kiss
    @cached_prev_thumb_or_kiss ||= if prev.present?
        prev.resized_blob_or_orig_or_placeholder_url
      else
        'kissy-transparent.png'
      end
  end

  def nek_thumb_or_kiss
    @cached_nek_thumb_or_kiss ||= if nek.present?
        nek.resized_blob_or_orig_or_placeholder_url
      else
        'kissy-transparent.png'
      end
  end

  def prev_path
    if prev.present?
      comfy_blog_post_path(@site.path, prev.year, prev.month, prev.slug)
    else
      ''
    end
  end

  def nek_path
    if nek.present?
      comfy_blog_post_path(@site.path, nek.year, nek.month, nek.slug)
    else
      ''
    end
  end

  def prev_css_classes
    classes = common_css_classes +
      %w(rounded-t-xl @xs:rounded-tr-none @xs:rounded-l-xl)
    classes += nsfw_css_classes if prev&.nsfw?
    classes << (prev.present? ? 'bg-cover' : 'bg-contain bg-origin-content bg-cyan-300')

    classes.join ' '
  end

  def nek_css_classes
    classes = common_css_classes +
      %w(rounded-b-xl @xs:rounded-bl-none @xs:rounded-r-xl)
    classes += nsfw_css_classes if nek&.nsfw?
    classes << (nek.present? ? 'bg-cover' : 'bg-contain bg-origin-content bg-cyan-300')

    classes.join ' '
  end

  def css_classes_for_category
    classes = %w(h-6 @xs:h-auto w-[7rem] @xs:w-[4.5rem] @sm:w-[6.5rem]
                 mx-auto @xs:-mx-[2.25rem] @sm:-mx-[3.25rem] -my-[0.75rem] @xs:my-auto 
                 px-0 py-2 z-10 
                 leading-[0.5rem] @xs:leading-[0.95rem] @sm:leading-[1.25rem]
                 text-center @xs:text-lg @sm:text-2xl font-bold
                 shadow-lg outline)
    classes << PostComponent::CAT_COMMON_CSS

    label = @category.present? ? @category.name.parameterize : 'all-posts'
    classes << PostComponent::CAT_UNIQUE_CSS[label]
    
    classes.join ' '
  end

  private

  def common_css_classes
    classes = %w(w-full @sm:w-auto h-20 p-2
                 basis-1/2
                 bg-center bg-no-repeat bg-white
                 cursor-pointer shadow-md transition
                 font-['Racing_Sans_One'])
    
    classes << "duration-#{PostComponent::DURATION}"
  end

  def nsfw_css_classes
    classes = %w(nsfw)
    
    classes << 'hover:blur-none' if @nsfw_options['mouseover']
    classes << 'blur-xs' unless @nsfw_options['always']

    classes
  end
end
