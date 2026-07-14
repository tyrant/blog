# frozen_string_literal: true

class AddQuotationRotationEnabledToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_sync_configs, :quotation_rotation_enabled, :boolean, default: false, null: false
  end
end
