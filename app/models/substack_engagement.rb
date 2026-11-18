# frozen_string_literal: true

# Who engaged with which piece of my Substack content: one row per account,
# piece (content_key "p-<post id>" or "c-<note id>") and kind. Written by
# Substack::EngagementScanner; idempotent, so rescans only add. Keyed by
# Substack's numeric user id rather than SubstackUser, so the thousands of
# one-off likers don't clutter Substack Users — an account only becomes a
# SubstackUser when it's made a favourite.
class SubstackEngagement < ApplicationRecord
  KINDS = %w[comment like restack reply].freeze

  validates :user_id, :content_key, presence: true
  validates :kind, inclusion: { in: KINDS }

  # Likes are cheap; comments, restacks and replies count for more. Breadth
  # (distinct pieces) and spread over time (months) reward consistency.
  SCORE_SQL = "COUNT(DISTINCT content_key) + 2 * COUNT(*) FILTER (WHERE kind <> 'like') + " \
              "3 * COUNT(DISTINCT date_trunc('month', occurred_at))"

  # A suggestion needs at least this many distinct pieces engaged with.
  SUGGESTION_MIN_PIECES = 3

  SORT_COLUMNS = {
    "score"    => "score",
    "pieces"   => "pieces",
    "months"   => "active_months",
    "comments" => "comments",
    "restacks" => "restacks",
    "replies"  => "replies",
    "likes"    => "likes",
    "last"     => "last_engaged_at"
  }.freeze

  # Upserts rows of { user_id:, handle:, name:, content_key:, kind:, occurred_at: };
  # a known handle or name is never overwritten with a blank one.
  def self.record!(rows)
    rows = rows.uniq { |row| row.values_at(:user_id, :content_key, :kind) }
    return if rows.empty?

    now = Time.current
    upsert_all(
      rows.map { |row| row.slice(:user_id, :handle, :name, :content_key, :kind, :occurred_at).merge(created_at: now, updated_at: now) },
      unique_by: %i[user_id content_key kind],
      on_duplicate: Arel.sql("handle = COALESCE(EXCLUDED.handle, substack_engagements.handle), " \
                             "name = COALESCE(EXCLUDED.name, substack_engagements.name), " \
                             "occurred_at = COALESCE(EXCLUDED.occurred_at, substack_engagements.occurred_at), " \
                             "updated_at = EXCLUDED.updated_at")
    )
  end

  # One row per account: user_id, latest handle and name, per-kind counts,
  # pieces, active_months, last_engaged_at and score.
  def self.leaderboard
    select(
      "user_id",
      "(ARRAY_AGG(handle ORDER BY updated_at DESC) FILTER (WHERE handle IS NOT NULL))[1] AS handle",
      "(ARRAY_AGG(name ORDER BY updated_at DESC) FILTER (WHERE name IS NOT NULL))[1] AS name",
      *KINDS.map { |kind| "COUNT(*) FILTER (WHERE kind = '#{kind}') AS #{kind.pluralize}" },
      "COUNT(DISTINCT content_key) AS pieces",
      "COUNT(DISTINCT date_trunc('month', occurred_at)) AS active_months",
      "MAX(occurred_at) AS last_engaged_at",
      "#{SCORE_SQL} AS score"
    ).group(:user_id)
  end

  # The most engaged accounts that aren't me and aren't favourites yet.
  def self.suggestions(order: "score", exclude_user_ids: [])
    column = SORT_COLUMNS.fetch(order.to_s, "score")
    leaderboard
      .where.not(user_id: [*exclude_user_ids, *SubstackUser.favourites.where.not(user_id: nil).pluck(:user_id)].compact)
      .having("COUNT(DISTINCT content_key) >= ?", SUGGESTION_MIN_PIECES)
      .order(Arel.sql("#{column} DESC NULLS LAST, score DESC, user_id"))
  end

  def self.profile_url(handle, user_id)
    handle.present? ? "https://substack.com/@#{handle}" : "https://substack.com/profile/#{user_id}"
  end
end
