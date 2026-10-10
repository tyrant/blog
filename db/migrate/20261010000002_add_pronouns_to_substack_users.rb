# frozen_string_literal: true

class AddPronounsToSubstackUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :substack_users, :pronouns, :string, null: false, default: "they/them"
  end
end
