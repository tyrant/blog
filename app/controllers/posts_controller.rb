class PostsController < Comfy::Blog::PostsController

  def prev_nek
    @cms_post = Comfy::Blog::Post.find(params[:id])
  end
end
