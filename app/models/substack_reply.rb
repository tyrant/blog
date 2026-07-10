# frozen_string_literal: true

class SubstackReply < ApplicationRecord
  validates :target_url, :comment_url, :replied_at, presence: true

  scope :chronological, -> { order(replied_at: :desc) }

  # Replies grouped by the account replied to, each group newest-first, and the
  # accounts themselves ordered by most-recent reply.
  def self.by_author
    chronological.group_by { |reply| reply.author_handle.presence || "(unknown)" }
  end
end
