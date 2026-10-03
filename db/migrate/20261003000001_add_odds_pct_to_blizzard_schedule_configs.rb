# frozen_string_literal: true

class AddOddsPctToBlizzardScheduleConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :blizzard_schedule_configs, :quotation_odds_pct, :integer, default: 24, null: false
    add_column :blizzard_schedule_configs, :unattached_odds_pct, :integer, default: 2, null: false
  end
end
