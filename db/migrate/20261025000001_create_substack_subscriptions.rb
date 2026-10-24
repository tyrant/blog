# frozen_string_literal: true

class CreateSubstackSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :substack_subscriptions do |t|
      t.bigint :subscription_id, null: false
      t.bigint :publication_id, null: false
      t.string :publication_name
      t.string :publication_subdomain
      t.string :publication_custom_domain
      t.bigint :author_id
      t.string :author_handle
      t.string :author_name
      t.string :membership_state
      t.datetime :subscribed_at
      t.boolean :follows_me
      t.boolean :subscribes_to_me
      t.integer :author_follower_count
      t.datetime :checked_at
      t.string :check_error
      t.timestamps
    end
    add_index :substack_subscriptions, :subscription_id, unique: true
    add_index :substack_subscriptions, :author_id
  end
end
