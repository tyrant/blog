# frozen_string_literal: true

class CreateSubstackQuotations < ActiveRecord::Migration[8.0]
  def change
    create_table :substack_quotations do |t|
      t.text   :quotation,   null: false
      t.string :comment_url, null: false
      t.string :post_url
      t.string :post_title
      t.string :author_url
      t.string :author_name
      t.timestamps
    end
  end
end
