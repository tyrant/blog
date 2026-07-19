# frozen_string_literal: true

class AddPostImageUrlToSubstackQuotations < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_quotations, :post_image_url, :string
  end
end
