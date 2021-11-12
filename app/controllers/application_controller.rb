class ApplicationController < ActionController::Base

  def index
    redirect_to comfy_blog_posts_path, notice: "I haven't actually coded this bit yet; just the blog for now"
  end

end
