class AddScratchpadTextToComfyBlogPosts < ActiveRecord::Migration[6.1]
  def change
    add_column :comfy_blog_posts, :scratchpad, :text
  end
end
