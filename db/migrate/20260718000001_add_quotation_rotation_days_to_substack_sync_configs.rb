# frozen_string_literal: true

class AddQuotationRotationDaysToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_sync_configs, :quotation_rotation_days, :integer, default: 7, null: false
    add_column :substack_sync_configs, :quotations_rotated_at, :datetime
  end
end
