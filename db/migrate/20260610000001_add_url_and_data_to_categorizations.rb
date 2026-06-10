class AddUrlAndDataToCategorizations < ActiveRecord::Migration[8.0]
  def change
    add_column :comfy_cms_categorizations, :url, :string
    add_column :comfy_cms_categorizations, :data, :jsonb, null: false, default: {}
  end
end
