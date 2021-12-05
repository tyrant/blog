class ApplicationController < ActionController::Base

  def index
    redirect_to comfy_blog_posts_path, notice: "I hadn't actually coded this bit yet! Just the blog for now."
  end

end
