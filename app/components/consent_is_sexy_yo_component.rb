class ConsentIsSexyYoComponent < ViewComponent::Base

  def initialize(nsfw_options:)
    @nsfw_options = nsfw_options
  end

  def banish_title
  end

  def banish_disabled?
    false
  end

  def banish_checked?
    @nsfw_options['banish']
  end

  def mouseover_title
    if mouseover_disabled?
      #"No point in opining on unblurring NSFW content when that content is hidden outright, yeah? Untick the \"Hide NSFW content\" checkbox to enable this checkbox."
    end
  end

  def mouseover_checked?
    @nsfw_options['mouseover']
  end

  def mouseover_disabled?
    banish_checked?
  end

  def always_title
    if always_disabled?

    end
  end

  def always_checked?
    @nsfw_options['always']
  end

  def always_disabled?
    banish_checked? || !mouseover_checked?
  end

end
