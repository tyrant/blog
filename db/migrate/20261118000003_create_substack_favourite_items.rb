# frozen_string_literal: true

# A recent post or Note by a favourite Substack account, for replying to by hand.
class CreateSubstackFavouriteItems < ActiveRecord::Migration[8.0]
  def change
    create_table :substack_favourite_items do |t|
      t.references :substack_user, null: false, foreign_key: true
      t.string :entity_key, null: false
      t.string :kind, null: false
      t.string :url, null: false
      t.string :title
      t.text :excerpt
      t.datetime :published_at, null: false
      t.boolean :liked, default: false, null: false
      t.boolean :restacked, default: false, null: false
      t.datetime :dismissed_at
      t.timestamps
    end
    add_index :substack_favourite_items, :entity_key, unique: true
    add_index :substack_favourite_items, :published_at
  end
end
