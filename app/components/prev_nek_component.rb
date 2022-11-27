class PrevNekComponent < ViewComponent::Base

  with_collection_parameter :category

  def initialize(category: nil, post:, site:, nsfw_options:)
    @category = category
    @post = post
    @site = site
    @nsfw_options = nsfw_options
  end

  def prev
    @post.prev category: @category, nsfw: !@nsfw_options['banish']
  end

  def nek
    @post.nek category: @category, nsfw: !@nsfw_options['banish']
  end

  def prev_css_classes
    classes = common_css_classes
    classes << "rounded-l-lg flex-row border-r-0 duration-#{PostIndexComponent::DURATION}"
    classes << nsfw_css_classes if prev.nsfw?

    classes.flatten
  end

  def nek_css_classes
    classes = common_css_classes
    classes << "rounded-r-lg flex-row-reverse border-l-0 duration-#{PostIndexComponent::DURATION}"
    classes << nsfw_css_classes if nek.nsfw?

    classes.flatten
  end

  private

  def common_css_classes
    %w(flex flex-row items-center md:basis-1/2 bg-white border shadow-md md:max-w-xl hover:bg-gray-100 dark:border-gray-700 dark:bg-gray-800 dark:hover:bg-gray-700)
  end

  def nsfw_css_classes
    [
      'nsfw',
      @nsfw_options['banish']    ? ['opacity-50'] : nil,
      @nsfw_options['mouseover'] ? 'hover:blur-none' : nil,
      !@nsfw_options['always']   ? 'blur-sm' : nil
    ].compact.flatten
  end
end
