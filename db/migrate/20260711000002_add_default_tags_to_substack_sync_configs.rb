# frozen_string_literal: true

# Publication tags (uuid + name) assigned to every new Substack post.
class AddDefaultTagsToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  TAGS = [
    { "name" => "writing",    "id" => "5c1da0ee-979f-4873-9e80-9ec09398e386" },
    { "name" => "advice",     "id" => "7e1c4cbe-05ec-4df4-a163-08174f40d4fd" },
    { "name" => "comedy",     "id" => "fd1dfc35-f0eb-4981-8150-7c21219d3e59" },
    { "name" => "creativity", "id" => "abe18d98-4e33-430e-a0a7-c4ef1e0013da" },
    { "name" => "breasts",    "id" => "c6d73e77-d5c6-4546-b85b-788e2806018c" }
  ].freeze

  def up
    add_column :substack_sync_configs, :default_tags, :jsonb
    execute <<~SQL.squish
      UPDATE substack_sync_configs SET default_tags = '#{TAGS.to_json}' WHERE default_tags IS NULL
    SQL
  end

  def down
    remove_column :substack_sync_configs, :default_tags
  end
end
