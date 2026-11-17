# frozen_string_literal: true

class ChangeReplyDrafterDefaultModel < ActiveRecord::Migration[8.0]
  def change
    change_column_default :reply_drafter_configs, :model, from: "claude-sonnet-5", to: "claude-sonnet-5-5"
  end
end
