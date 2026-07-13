# frozen_string_literal: true

class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.string :substack_tag_id
      t.timestamps
    end
    add_index :tags, "lower(name)", unique: true, name: "index_tags_on_lower_name"
    add_index :tags, :substack_tag_id, unique: true, where: "substack_tag_id IS NOT NULL"

    create_table :blog_post_tags do |t|
      t.references :comfy_blog_post, null: false, foreign_key: { to_table: :comfy_blog_posts }
      t.references :tag, null: false, foreign_key: true
      t.timestamps
    end
    add_index :blog_post_tags, %i[comfy_blog_post_id tag_id], unique: true
  end
end
