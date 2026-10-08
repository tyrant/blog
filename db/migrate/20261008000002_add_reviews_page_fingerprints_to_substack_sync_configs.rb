# frozen_string_literal: true

class AddReviewsPageFingerprintsToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_sync_configs, :reviews_page_fingerprints, :jsonb, default: {}, null: false
  end
end
