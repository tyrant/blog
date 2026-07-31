# frozen_string_literal: true

class CreateBlueskySyncConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :bluesky_sync_configs do |t|
      t.string :handle
      t.text :app_password
      t.string :service_host, null: false, default: "https://bsky.social"
      t.text :lead
      t.text :lead_shite

      t.timestamps
    end
  end
end
