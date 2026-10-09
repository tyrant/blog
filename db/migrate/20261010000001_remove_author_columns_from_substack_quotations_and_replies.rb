# frozen_string_literal: true

class RemoveAuthorColumnsFromSubstackQuotationsAndReplies < ActiveRecord::Migration[8.0]
  def change
    remove_column :substack_quotations, :author_url, :string
    remove_column :substack_quotations, :author_name, :string
    remove_column :substack_quotations, :author_user_id, :bigint
    remove_index :substack_replies, :author_handle, name: "index_substack_replies_on_author_handle"
    remove_column :substack_replies, :author_name, :string
    remove_column :substack_replies, :author_handle, :string
    remove_column :substack_replies, :author_user_id, :bigint
  end
end
