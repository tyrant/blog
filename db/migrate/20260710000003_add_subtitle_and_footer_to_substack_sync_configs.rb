# frozen_string_literal: true

# The standard blocks every mirrored Substack post carries: a fixed subtitle and
# the footer boilerplate (subscribe CTA through the "Subscribe now" button),
# stored as the ProseMirror block array captured from a reference post.
class AddSubtitleAndFooterToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_sync_configs, :subtitle, :text
    add_column :substack_sync_configs, :footer_json, :jsonb
  end
end
