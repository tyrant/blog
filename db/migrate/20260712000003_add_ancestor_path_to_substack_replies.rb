# frozen_string_literal: true

# The reply comment's Substack ancestor path (dot-separated comment ids), used to
# nest replies that belong to the same thread under their ancestor.
class AddAncestorPathToSubstackReplies < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_replies, :ancestor_path, :string
  end
end
