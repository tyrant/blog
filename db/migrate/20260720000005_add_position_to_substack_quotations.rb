# frozen_string_literal: true

class AddPositionToSubstackQuotations < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_quotations, :position, :integer
  end
end
