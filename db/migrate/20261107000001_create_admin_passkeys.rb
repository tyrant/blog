# frozen_string_literal: true

class CreateAdminPasskeys < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_passkeys do |t|
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, null: false, default: 0
      t.string :nickname, null: false
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :admin_passkeys, :external_id, unique: true
  end
end
