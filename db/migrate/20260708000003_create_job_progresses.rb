# frozen_string_literal: true

# Live progress for long-running background jobs, one upserted row per job type
# (key). The worker writes it; the admin polls it. See JobProgressReporting.
class CreateJobProgresses < ActiveRecord::Migration[8.0]
  def change
    create_table :job_progresses do |t|
      t.string   :key,       null: false
      t.string   :label,     null: false
      t.integer  :total,     null: false, default: 0
      t.integer  :completed, null: false, default: 0
      t.string   :status,    null: false, default: "running"
      t.string   :detail
      t.datetime :started_at
      t.timestamps

      t.index :key, unique: true
    end
  end
end
