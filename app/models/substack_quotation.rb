# frozen_string_literal: true

class SubstackQuotation < ApplicationRecord
  validates :quotation, :comment_url, presence: true

  before_create :assign_position

  scope :chronological, -> { order(created_at: :desc) }
  # The display order on the Reviews pages — set manually by drag-to-reorder in the
  # admin (SubstackQuotation.reorder!); new quotations append to the end.
  scope :by_position, -> { order(:position, :id) }
  # Quotations complete enough to render as a triplet. Author is optional —
  # QuotationBlock renders the name as plain text when author_url is blank.
  scope :featurable, -> { where.not(post_url: [nil, ""]) }
  # Manually marked (admin checkbox) as reading fine on their own, out of their
  # parent Post's context — eligible for the text-only widget PostSyncer slots
  # above every Substack post. Off by default: most blurbs need that context.
  scope :previewable, -> { where(previewable: true) }

  # Persist a manual Reviews-page order from the admin drag-to-reorder list —
  # `ordered_ids` is the quotation ids in their new top-to-bottom order.
  def self.reorder!(ordered_ids)
    transaction do
      ordered_ids.each_with_index { |id, index| where(id: id).update_all(position: index) }
    end
  end

  # Up to `count` random quotations from `scope` (default featurable), distinct
  # by quote text, and excluding any left on the given Substack post (no point
  # pointing a reader at the post they're already on).
  def self.sample_excluding(post_url, count, scope: featurable)
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
      post_id:        resolved.post_id,
      author_url:     resolved.author_url,
      author_name:    resolved.author_name
    )
  end

  private

  def assign_position
    self.position ||= (self.class.maximum(:position) || -1) + 1
  end
end
