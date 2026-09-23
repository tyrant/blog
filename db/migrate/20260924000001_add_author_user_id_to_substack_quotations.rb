# frozen_string_literal: true

class AddAuthorUserIdToSubstackQuotations < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_quotations, :author_user_id, :bigint
  end
end
