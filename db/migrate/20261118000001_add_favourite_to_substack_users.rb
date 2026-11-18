# frozen_string_literal: true

class AddFavouriteToSubstackUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_users, :favourite, :boolean, default: false, null: false
    add_index :substack_users, :favourite, where: "favourite"
  end
end
