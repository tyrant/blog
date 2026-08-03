# frozen_string_literal: true

class RemoveSubtitleDefaultFromSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    remove_column :substack_sync_configs, :subtitle_default, :text
  end
end
