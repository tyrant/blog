# frozen_string_literal: true

class AddNotesToSubstackQuotations < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_quotations, :notes, :jsonb, default: [], null: false
  end
end
