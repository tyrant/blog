# frozen_string_literal: true

class SubstackQuotation < ApplicationRecord
  validates :quotation, :comment_url, presence: true

  scope :chronological, -> { order(created_at: :desc) }
  # Quotations complete enough to render as a linked triplet.
  scope :featurable, -> { where.not(post_url: [nil, ""]).where.not(author_url: [nil, ""]) }

  # Up to `count` random featurable quotations, distinct by quote text, and
  # excluding any left on the given Substack post (no point pointing a reader at
  # the post they're already on).
  def self.sample_excluding(post_url, count)
    scope = featurable
    scope = scope.where.not(post_url: post_url) if post_url.present?
    scope.order(Arel.sql("RANDOM()")).limit(count * 5).to_a
      .uniq { |quotation| quotation.quotation.to_s.strip.downcase }
      .first(count)
  end

  # Fill post + author metadata from the comment's Substack data. Invoked by the
  # admin form on create — the user supplies only the comment URL and the blurb.
  def populate_from_substack!(client: nil)
    resolved = Substack::QuotationResolver.execute(comment_url: comment_url, client: client)
    assign_attributes(
      post_url:       resolved.post_url,
      post_title:     resolved.post_title,
      post_image_url: resolved.post_image_url,
      author_url:     resolved.author_url,
      author_name:    resolved.author_name
    )
  end
end
