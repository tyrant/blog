# frozen_string_literal: true

class CreateMediumSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    create_table :medium_sync_configs do |t|
      t.text :title_template,   default: "{{title}}"
      t.text :subtitle
      t.text :content_template, default: "{{content}}"
      t.text :link_template,    default: "original: {{url}}"
      t.text :footer_html

      t.timestamps
    end
  end
end
