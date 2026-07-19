# frozen_string_literal: true

class AddPostEmbedToSubstackQuotations < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_quotations, :post_embed, :jsonb
  end
end
