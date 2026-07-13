# frozen_string_literal: true

class AddSubstackAudienceToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :comfy_blog_posts, :substack_audience, :string, default: "everyone", null: false
  end
end
