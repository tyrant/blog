# frozen_string_literal: true

class AddPostIdToSubstackQuotations < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_quotations, :post_id, :bigint
  end
end
