# frozen_string_literal: true

# The Substack post's own like count (❤ reaction_count), refreshed daily. Folded
# into each of the post's blizzard entries' repost weights. Nullable — nil means
# not yet fetched, treated as 0.
class AddSubstackLikesToComfyBlogPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :comfy_blog_posts, :substack_likes, :integer
  end
end
