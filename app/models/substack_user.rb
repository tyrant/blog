# frozen_string_literal: true

# One Substack account, shared by its SubstackQuotations and SubstackReplies.
class SubstackUser < ApplicationRecord
  has_many :quotations, class_name: "SubstackQuotation", dependent: :nullify
  has_many :replies, class_name: "SubstackReply", dependent: :nullify

  normalizes :handle, with: ->(handle) { handle.strip.delete_prefix("@").presence }
  normalizes :name, with: ->(name) { name.strip.presence }

  validates :user_id, uniqueness: true, allow_nil: true
  validates :handle, uniqueness: { case_sensitive: false }, allow_nil: true
  validate :identifiable

  # Reviews page fingerprints use quotation updated_at, so a rename must flag those pages.
  after_update :touch_quotations, if: -> { saved_change_to_name? || saved_change_to_handle? }

  # Handles can change hands, so the numeric id wins; name alone only when neither is known.
  def self.identify(user_id: nil, handle: nil, name: nil)
    user_id = user_id.presence
    handle  = handle.presence
    name    = name.presence
    return nil unless user_id || handle || name

    transaction do
      user = if user_id
               find_or_initialize_by(user_id: user_id)
             elsif handle
               with_handle(handle).first || new
             else
               find_or_initialize_by(user_id: nil, handle: nil, name: name)
             end

      if handle
        holder = with_handle(handle).where.not(id: user.id).first
        if holder && holder.user_id.nil?
          # Same account, recorded before its id was known.
          user.save! if user.new_record?
          user.absorb!(holder)
        elsif holder
          holder.update!(handle: nil) # a handle since taken by another account
        end
      end

      user.handle = handle if handle
      user.name = name if name
      user.save!
      user
    end
  end

  def self.with_handle(handle)
    where("lower(handle) = ?", handle.to_s.downcase)
  end

  def self.alphabetical
    order(Arel.sql("lower(coalesce(name, handle, '')), id"))
  end

  def self.search(query)
    return all if query.blank?

    term = "%#{sanitize_sql_like(query.strip.delete_prefix('@'))}%"
    where("name ILIKE :term OR handle ILIKE :term OR user_id::text = :exact", term: term, exact: query.strip)
  end

  def self.with_link_counts
    select("substack_users.*",
           "(SELECT COUNT(*) FROM substack_quotations WHERE substack_user_id = substack_users.id) AS quotations_count",
           "(SELECT COUNT(*) FROM substack_replies WHERE substack_user_id = substack_users.id) AS replies_count")
  end

  def profile_url
    "https://substack.com/@#{handle}" if handle.present?
  end

  def absorb!(other)
    other.quotations.update_all(substack_user_id: id)
    other.replies.update_all(substack_user_id: id)
    other.reload.destroy!
  end

  private

  def identifiable
    errors.add(:base, "Needs a user id, handle or name") if user_id.blank? && handle.blank? && name.blank?
  end

  def touch_quotations
    quotations.touch_all
  end
end
