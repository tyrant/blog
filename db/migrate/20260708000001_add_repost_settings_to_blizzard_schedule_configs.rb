# frozen_string_literal: true

# Repurposes the singleton for popularity-weighted reposting: how often to repost
# (interval_minutes), how long an entry rests after a repost (cooldown_hours), and
# when the last repost fired. The old `schedule` jsonb (the retired forecast
# calendar's saved arrangement) is left in place, now unused.
class AddRepostSettingsToBlizzardScheduleConfigs < ActiveRecord::Migration[8.0]
  def change
    change_table :blizzard_schedule_configs, bulk: true do |t|
      t.integer  :interval_minutes, null: false, default: 30
      t.integer  :cooldown_hours,   null: false, default: 12
      t.datetime :last_reposted_at
    end
  end
end
