# frozen_string_literal: true

class AddReviewsExtraDraftIdsToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_sync_configs, :reviews_extra_draft_ids, :jsonb, null: false, default: []
  end
end
