# frozen_string_literal: true

# Old author_* columns stay (model-ignored) until the backfill is confirmed on prod.
class CreateSubstackUsers < ActiveRecord::Migration[8.0]
  HANDLE_PATTERNS = [%r{substack\.com/@([^/?#]+)}, %r{substack\.com/profile/\d+-([^/?#]+)}].freeze

  class MigrationUser < ActiveRecord::Base
    self.table_name = "substack_users"
  end

  def up
    create_table :substack_users do |t|
      t.bigint :user_id
      t.string :handle
      t.string :name
      t.timestamps
    end
    add_index :substack_users, :user_id, unique: true, where: "user_id IS NOT NULL"
    add_index :substack_users, "lower(handle)", unique: true, where: "handle IS NOT NULL",
              name: "index_substack_users_on_lower_handle"

    add_reference :substack_quotations, :substack_user, foreign_key: true
    add_reference :substack_replies, :substack_user, foreign_key: true

    backfill
  end

  def down
    remove_reference :substack_replies, :substack_user, foreign_key: true
    remove_reference :substack_quotations, :substack_user, foreign_key: true
    drop_table :substack_users
  end

  private

  # Oldest first, so each account ends up with its most recently seen name/handle.
  def backfill
    rows = select_rows(<<~SQL).map { |table, id, uid, url, handle, name, _at| [table, id, uid, handle.presence || handle_from(url), name.presence] }
      SELECT 'substack_quotations', id, author_user_id, author_url, NULL, author_name, updated_at FROM substack_quotations
      UNION ALL
      SELECT 'substack_replies', id, author_user_id, NULL, author_handle, author_name, updated_at FROM substack_replies
      ORDER BY 7, 2
    SQL

    users = []
    by_id = {}
    by_handle = {}
    by_name = {}

    rows.each do |table, id, uid, handle, name|
      uid = uid&.to_i
      next unless uid || handle || name

      key = handle&.downcase
      user = (uid && by_id[uid]) || (!uid && key && by_handle[key]) || (!uid && !key && by_name[name])
      unless user
        user = { user_id: uid, handle: nil, name: nil, members: [] }
        users << user
      end
      user[:user_id] ||= uid

      if key && by_handle[key] && !by_handle[key].equal?(user)
        other = by_handle[key]
        if other[:user_id].nil?
          # Same account, recorded before its id was known.
          user[:members].concat(other[:members])
          users.delete(other)
          by_name.delete_if { |_n, u| u.equal?(other) }
        else
          other[:handle] = nil # a handle since taken by another account
        end
      end

      user[:handle] = handle if handle
      user[:name] = name if name
      user[:members] << [table, id]
      by_id[uid] = user if uid
      by_handle[key] = user if key
      by_name[name] = user if name && !uid && !key
    end

    say "Backfilling #{users.size} Substack users from #{rows.size} quotations/replies"
    unparsed = rows.count { |table, _id, _uid, handle, _name| table == "substack_quotations" && handle.nil? }
    say "#{unparsed} quotations had no parseable profile handle", true if unparsed.positive?

    users.each do |user|
      record = MigrationUser.create!(user.slice(:user_id, :handle, :name))
      user[:members].group_by(&:first).each do |table, members|
        execute(<<~SQL)
          UPDATE #{table} SET substack_user_id = #{record.id} WHERE id IN (#{members.map(&:last).map(&:to_i).join(",")})
        SQL
      end
    end
  end

  def handle_from(url)
    HANDLE_PATTERNS.each do |pattern|
      handle = url.to_s[pattern, 1]
      return handle if handle.present?
    end
    nil
  end
end
