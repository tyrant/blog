# frozen_string_literal: true

# Medium post-mirroring (Selenium-driven) has been retired; its config table is
# no longer referenced.
class DropMediumSyncConfigs < ActiveRecord::Migration[8.0]
  def up
    drop_table :medium_sync_configs
  end

  def down
    create_table :medium_sync_configs do |t|
      t.text :title_template, default: "{{title}}"
      t.text :subtitle
      t.text :content_template, default: "{{content}}"
      t.text :link_template, default: "original: {{url}}"
      t.text :footer_html
      t.timestamps
    end
  end
end
