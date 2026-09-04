# frozen_string_literal: true

class AddDataToBlizzardScheduleConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :blizzard_schedule_configs, :data, :jsonb, default: {}, null: false
  end
end
