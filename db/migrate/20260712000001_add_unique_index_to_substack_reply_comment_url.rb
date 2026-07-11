# frozen_string_literal: true

# A reply URL should only be logged once.
class AddUniqueIndexToSubstackReplyCommentUrl < ActiveRecord::Migration[8.0]
  def up
    # Drop any pre-existing duplicates (keep the earliest) so the index can build.
    execute <<~SQL.squish
      DELETE FROM substack_replies a USING substack_replies b
      WHERE a.comment_url = b.comment_url AND a.id > b.id
    SQL
    add_index :substack_replies, :comment_url, unique: true
  end

  def down
    remove_index :substack_replies, :comment_url
  end
end
