# frozen_string_literal: true

class CreateBlizzardScheduleConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :blizzard_schedule_configs do |t|
      t.jsonb :schedule, null: false, default: {}

      t.timestamps
    end
  end
end
