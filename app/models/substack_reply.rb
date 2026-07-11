# frozen_string_literal: true

class SubstackReply < ApplicationRecord
  validates :target_url, :comment_url, :replied_at, presence: true
  validates :comment_url, uniqueness: true

  scope :chronological, -> { order(replied_at: :desc) }

  # Replies grouped by the account replied to, each group newest-first, and the
  # accounts themselves ordered by most-recent reply.
  def self.by_author(query = nil)
    scope = chronological
    if query.present?
      like  = "%#{query.strip.downcase}%"
      scope = scope.where("LOWER(author_handle) LIKE :q OR LOWER(COALESCE(author_name, '')) LIKE :q", q: like)
    end
    scope.group_by { |reply| reply.author_handle.presence || "(unknown)" }
  end
end
