class PostIndexComponent < ViewComponent::Base

  DURATION = 200

  def initialize(post_index:, cms_site:, nsfw_options:)
    @post = post_index
    @cms_site = cms_site
    @nsfw_options = nsfw_options
  end

  private

  def css_classes
    names = ['card', "duration-#{DURATION}"]

    names << nsfw_css_classes if @post.nsfw?

    names.flatten
  end

  def css_classes_for_category(category)
    {
      'whimsy' => 'bg-indigo-100 text-indigo-800',
      'nsfw' => 'bg-red-800 text-red-100',
      'very-bad-advice' => 'bg-lime-100 text-lime-800'
    }[category.label.parameterize]
  end

  def nsfw_css_classes
    [
      @nsfw_options['banish']    ? ['hidden', 'opacity-0'] : nil,
      @nsfw_options['mouseover'] ? 'hover:blur-none' : nil,
      !@nsfw_options['always']   ? 'blur-sm' : nil
    ].compact.flatten
  end
end
