# frozen_string_literal: true

# A recent post or Note by a favourite Substack account, listed on Substack
# Favourites for replying to by hand. Upserted by Substack::FavouritesRefresher;
# "Done" sets dismissed_at, which a refresh never clears.
class SubstackFavouriteItem < ApplicationRecord
  KINDS = %w[post note].freeze

  belongs_to :substack_user

  validates :entity_key, presence: true, uniqueness: true
  validates :kind, inclusion: { in: KINDS }
  validates :url, :published_at, presence: true

  scope :pending, -> { where(dismissed_at: nil) }
  scope :newest_first, -> { order(published_at: :desc, id: :desc) }
  scope :from_favourites, -> { joins(:substack_user).where(substack_users: { favourite: true }) }

  def note? = kind == "note"
  def post? = kind == "post"

  # The Note's comment id ("c-123" → "123").
  def comment_id
    entity_key.delete_prefix("c-") if note?
  end

  # The ids of those `items` I've already replied to, per SubstackReply: a reply
  # whose thread includes the Note, or a comment on the post.
  def self.replied_ids(items)
    items = items.to_a
    return Set.new if items.empty?

    replies = SubstackReply.where(replied_at: items.map(&:published_at).min..).pluck(:target_url, :ancestor_path)
    thread_ids = replies.flat_map { |target, path| [target.to_s[/c-(\d+)/, 1], *path.to_s.split(".")] }.compact.to_set
    targets = replies.map(&:first).compact

    items.select do |item|
      item.note? ? thread_ids.include?(item.comment_id) : targets.any? { |target| target.start_with?("#{item.url}/") || target == item.url }
    end.to_set(&:id)
  end
end
