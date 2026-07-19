# frozen_string_literal: true

class AddReviewsDraftIdToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_sync_configs, :reviews_draft_id, :bigint
  end
end
