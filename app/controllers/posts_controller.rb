class PostsController < Comfy::Blog::PostsController

  def index
    @show_other_books = true
    
    scope =
      if params[:year]
        scope = @cms_site.blog_posts.published.for_year(params[:year])
        params[:month] ? scope.for_month(params[:month]) : scope
      else
        @cms_site.blog_posts.published
      end
  
    scope = scope.for_category(params[:category]) if params[:category]
    scope = scope.includes(categorizations: :category).order(:published_at).reverse_order
  
    @blog_posts = comfy_paginate(scope, per_page: ComfyBlog.config.posts_per_page)
    render layout: ComfyBlog.config.app_layout
  end

  def prev_nek
    @cms_post = Comfy::Blog::Post.find(params[:id])
  end
end
