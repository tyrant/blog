# frozen_string_literal: true

# Persisted, admin-editable settings for the Reply Drafter: the instruction brief
# plus the reply count / agree-disagree balance / length knobs.
class CreateReplyDrafterConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :reply_drafter_configs do |t|
      t.text    :instructions
      t.integer :count,  null: false, default: 6
      t.string  :split,  null: false, default: "balanced"
      t.string  :length, null: false, default: "1-3"
      t.timestamps
    end
  end
end
