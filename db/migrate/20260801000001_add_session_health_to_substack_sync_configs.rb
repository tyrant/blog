# frozen_string_literal: true

class AddSessionHealthToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_sync_configs, :session_healthy, :boolean, null: false, default: true
    add_column :substack_sync_configs, :session_checked_at, :datetime
    add_column :substack_sync_configs, :session_error, :string
  end
end
