class ApplicationController < ActionController::Base

  before_action :unstringly_type_cookies
  before_action :init_nav_items

  def index
    redirect_to comfy_blog_posts_path, notice: "I hadn't actually coded this bit yet! Just the blog for now."
  end

  def unstringly_type_cookies
    ['unblur_nsfw_on_mouseover', 'unblur_nsfw_always'].each do |cookie_key|
      {
        'true' => true,
        'false' => false
      }.each do |wrong_value, right_value|
        request.cookies[cookie_key] = right_value if request.cookies[cookie_key] == wrong_value
      end
    end
  end

  def init_nav_items
    @nav_items = [{ label: 'All posts', path: comfy_blog_posts_path }]

    Comfy::Cms::Category.where.not(label: 'wysiwyg').order('label desc').each do |cat|
      @nav_items << { 
        label: cat.label, 
        path: comfy_blog_posts_path(category: cat.label) 
      }
    end
  end
end
