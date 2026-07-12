# frozen_string_literal: true

# The Reply Drafter length is now a plain sentence count, not a range enum.
class ChangeReplyDrafterLengthToNumber < ActiveRecord::Migration[8.0]
  def up
    change_column_default :reply_drafter_configs, :length, "2"
    execute "UPDATE reply_drafter_configs SET length = '2' WHERE length !~ '^[0-9]+$'"
  end

  def down
    change_column_default :reply_drafter_configs, :length, "1-3"
  end
end
