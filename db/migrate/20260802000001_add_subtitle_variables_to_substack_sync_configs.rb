# frozen_string_literal: true

class AddSubtitleVariablesToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_sync_configs, :subtitle_variables_json, :text
  end
end
