# frozen_string_literal: true

# Identity of the Substack publication we mirror Comfy posts into: the API host
# (drafts live on the publication subdomain) and the author id used as the byline.
class AddPublicationFieldsToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def up
    add_column :substack_sync_configs, :publication_host, :string
    add_column :substack_sync_configs, :author_id, :bigint

    # Backfill the singleton with this blog's known Substack identity so the
    # syncer works before the admin form (phase 2) exists to set it.
    execute <<~SQL.squish
      UPDATE substack_sync_configs
      SET publication_host = 'mikeyclarke.substack.com', author_id = 4619740
      WHERE publication_host IS NULL
    SQL
  end

  def down
    remove_column :substack_sync_configs, :publication_host
    remove_column :substack_sync_configs, :author_id
  end
end
