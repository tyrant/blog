# frozen_string_literal: true

# The Comfy<->Substack link now lives in the Substack categorization's
# data["id"] (single source of truth); the per-post draft-id column is retired.
class RemoveSubstackDraftIdFromComfyBlogPosts < ActiveRecord::Migration[8.0]
  def change
    remove_column :comfy_blog_posts, :substack_draft_id, :bigint
  end
end
