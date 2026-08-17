# frozen_string_literal: true

class AddReviewsPageSizeToSubstackSyncConfigs < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_sync_configs, :reviews_page_size, :integer, default: 20, null: false
  end
end
