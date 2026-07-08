# frozen_string_literal: true

# Hourly point-in-time snapshot of the Substack Blizzard totals (posts / blizzard
# entries / notes), for the "Totals over time" line graph.
class CreateBlizzardStatSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :blizzard_stat_snapshots do |t|
      t.datetime :captured_at, null: false
      t.integer  :posts,   null: false, default: 0
      t.integer  :entries, null: false, default: 0
      t.integer  :notes,   null: false, default: 0
      t.timestamps

      t.index :captured_at
    end
  end
end
