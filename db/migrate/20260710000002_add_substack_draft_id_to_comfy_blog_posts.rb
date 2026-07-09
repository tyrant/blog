# frozen_string_literal: true

# Tracks the Substack draft a post is mirrored to, so re-syncs update that draft
# (PUT) rather than creating a duplicate.
class AddSubstackDraftIdToComfyBlogPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :comfy_blog_posts, :substack_draft_id, :bigint
  end
end
