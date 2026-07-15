# frozen_string_literal: true

class AddSubtitleDefaultToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_sync_configs, :subtitle_default, :text
  end
end
