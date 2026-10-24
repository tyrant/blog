# frozen_string_literal: true

# A publication the owner subscribes to, for pruning under Substack's 5,000-subscription cap.
class SubstackSubscription < ApplicationRecord
  FREE = "free_signup"

  SORT_COLUMNS = {
    "subscribed_at" => "subscribed_at",
    "publication"   => "lower(publication_name)",
    "author"        => "lower(coalesce(author_name, author_handle, ''))",
    "followers"     => "author_follower_count"
  }.freeze

  FILTERS = {
    "candidates"   => "Not following back, no interaction",
    "follows_back" => "Following or subscribing back",
    "unchecked"    => "Not checked yet",
    "errors"       => "Check failed",
    "all"          => "All"
  }.freeze

  scope :free, -> { where(membership_state: FREE) }
  scope :unchecked, -> { where(checked_at: nil) }
  scope :errored, -> { where.not(check_error: nil) }
  scope :reciprocated, -> { where(follows_me: true).or(where(subscribes_to_me: true)) }

  # Interactions are matched through the SubstackUser sharing the author's Substack user id.
  QUOTATIONS_SQL = "(SELECT COUNT(*) FROM substack_quotations JOIN substack_users ON substack_users.id = substack_quotations.substack_user_id " \
                   "WHERE substack_users.user_id = substack_subscriptions.author_id)"
  REPLIES_SQL = "(SELECT COUNT(*) FROM substack_replies JOIN substack_users ON substack_users.id = substack_replies.substack_user_id " \
                "WHERE substack_users.user_id = substack_subscriptions.author_id)"

  def self.with_interaction_counts
    select("substack_subscriptions.*", "#{QUOTATIONS_SQL} AS quotations_count", "#{REPLIES_SQL} AS replies_count")
  end

  # Paid subscriptions are never offered for pruning.
  def self.candidates
    free.where.not(checked_at: nil).where(check_error: nil)
        .where(follows_me: false, subscribes_to_me: false)
        .where("#{QUOTATIONS_SQL} = 0 AND #{REPLIES_SQL} = 0")
  end

  def self.filtered(filter)
    case filter.to_s
    when "all"          then all
    when "follows_back" then reciprocated
    when "unchecked"    then unchecked
    when "errors"       then errored
    else candidates
    end
  end

  def self.search(query)
    return all if query.blank?

    term = "%#{sanitize_sql_like(query.strip.delete_prefix('@'))}%"
    where("publication_name ILIKE :term OR publication_subdomain ILIKE :term OR author_name ILIKE :term OR author_handle ILIKE :term", term: term)
  end

  # Unknown columns fall back to subscribed date, anything but "asc" to descending; blanks always sort last.
  def self.sorted_by(column, direction)
    expression = SORT_COLUMNS.fetch(column.to_s, SORT_COLUMNS["subscribed_at"])
    direction  = direction.to_s.casecmp?("asc") ? "ASC" : "DESC"
    order(Arel.sql("#{expression} #{direction} NULLS LAST, id"))
  end

  def publication_url
    publication_custom_domain.present? ? "https://#{publication_custom_domain}" : "https://#{publication_subdomain}.substack.com"
  end

  def profile_url
    "https://substack.com/@#{author_handle}" if author_handle.present?
  end

  def paid?
    membership_state != FREE
  end
end
