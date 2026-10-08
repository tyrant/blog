# frozen_string_literal: true

class CreateSubstackPendingPublishes < ActiveRecord::Migration[8.0]
  def change
    create_table :substack_pending_publishes do |t|
      t.bigint :draft_id, null: false
      t.string :title
      t.timestamps
    end
    add_index :substack_pending_publishes, :draft_id, unique: true
  end
end
