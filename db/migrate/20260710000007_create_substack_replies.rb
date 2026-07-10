# frozen_string_literal: true

# A log of replies the user has posted on Substack: what was replied to, the
# reply's own URL, the owner of the target (auto-resolved), and when — for
# per-user timeline histories.
class CreateSubstackReplies < ActiveRecord::Migration[8.0]
  def change
    create_table :substack_replies do |t|
      t.string   :target_url,     null: false
      t.string   :comment_url,    null: false
      t.string   :author_name
      t.string   :author_handle
      t.bigint   :author_user_id
      t.datetime :replied_at,     null: false
      t.timestamps

      t.index :author_handle
      t.index :replied_at
    end
  end
end
