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
    classes << %w(rounded-t-lg sm:rounded-l-lg border-b-none sm:border-r-none text-right)
    classes << nsfw_css_classes if prev.nsfw?

    classes.flatten.join ' '
  end

  def nek_css_classes
    classes = common_css_classes
    classes << %w(rounded-b-lg sm:rounded-r-lg border-t-none sm:border-l-none)
    classes << nsfw_css_classes if nek.nsfw?

    classes.flatten.join ' '
  end

  def css_classes_for_category_label(category)
    classes = %w(order-first sm:order-none text-center text-lg px-1 py-1 w-auto sm:w-20 mx-auto sm:-mx-10 md:w-24 md:-mx-12 -my-0 bg-white z-10 rounded font-bold sm:opacity-90 leading-tight)
    classes << PostIndexComponent::CAT_CSS[category.label.parameterize] if category.present?
    
    classes.flatten.join ' '
  end

  private

  def common_css_classes
    %w(w-full sm:w-auto flex basis-1/2 bg-white border shadow-md hover:bg-gray-100 dark:border-gray-700 dark:bg-gray-800 dark:hover:bg-gray-700) + ["duration-#{PostIndexComponent::DURATION}"]
  end

  def nsfw_css_classes
    classes = ['nsfw']
    classes << 'opacity-50' if @nsfw_options['banish']
    classes << 'hover:blur-none' if @nsfw_options['mouseover']
    classes << 'blur-sm' unless @nsfw_options['always']

    classes
  end
end
