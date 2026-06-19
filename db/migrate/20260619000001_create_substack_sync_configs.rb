# frozen_string_literal: true

class CreateSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :substack_sync_configs do |t|
      t.text :session_cookie

      t.timestamps
    end
  end
end
