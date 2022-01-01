module ApplicationHelper


  def css_classes_for(post:, unblur_nsfw_on_mouseover:, unblur_nsfw_always:)
    classes = ['card', 'text-white']
    classes << 'nsfw' if post.nsfw?
    classes << 'blurred' unless unblur_nsfw_always
    classes << 'unblurred-on-mouseover' if unblur_nsfw_on_mouseover

    classes.join ' '
  end
end
