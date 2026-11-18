# frozen_string_literal: true

# One row per (account, piece of my content, kind of engagement) — who commented
# on, liked, restacked or replied to which of my posts and Notes.
class CreateSubstackEngagements < ActiveRecord::Migration[8.0]
  def change
    create_table :substack_engagements do |t|
      t.bigint :user_id, null: false
      t.string :handle
      t.string :name
      t.string :content_key, null: false
      t.string :kind, null: false
      t.datetime :occurred_at
      t.timestamps
    end
    add_index :substack_engagements, %i[user_id content_key kind], unique: true
  end
end
