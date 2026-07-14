# frozen_string_literal: true

class SubstackQuotation < ApplicationRecord
  validates :quotation, :comment_url, presence: true

  scope :chronological, -> { order(created_at: :desc) }

  # Fill post + author metadata from the comment's Substack data. Invoked by the
  # admin form on create — the user supplies only the comment URL and the blurb.
  def populate_from_substack!(client: nil)
    resolved = Substack::QuotationResolver.execute(comment_url: comment_url, client: client)
    assign_attributes(
      post_url:    resolved.post_url,
      post_title:  resolved.post_title,
      author_url:  resolved.author_url,
      author_name: resolved.author_name
    )
  end
end
