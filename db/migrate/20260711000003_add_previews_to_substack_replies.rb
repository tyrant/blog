# frozen_string_literal: true

# Short content previews captured at log time: the target's title/text and the
# reply's text, shown as the link labels in the tracker.
class AddPreviewsToSubstackReplies < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_replies, :target_preview, :text
    add_column :substack_replies, :reply_preview, :text
  end
end
