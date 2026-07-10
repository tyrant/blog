# frozen_string_literal: true

# The Claude model the Reply Drafter uses, selectable per-run and persisted.
class AddModelToReplyDrafterConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :reply_drafter_configs, :model, :string, null: false, default: "claude-sonnet-5"
  end
end
