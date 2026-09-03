# frozen_string_literal: true

class AddPreviewableToSubstackQuotations < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_quotations, :previewable, :boolean, default: false, null: false
  end
end
