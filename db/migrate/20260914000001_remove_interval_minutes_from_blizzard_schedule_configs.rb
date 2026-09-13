# frozen_string_literal: true

class RemoveIntervalMinutesFromBlizzardScheduleConfigs < ActiveRecord::Migration[8.0]
  def change
    remove_column :blizzard_schedule_configs, :interval_minutes, :integer, default: 30, null: false
  end
end
