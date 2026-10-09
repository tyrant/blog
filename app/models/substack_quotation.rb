# frozen_string_literal: true

class SubstackQuotation < ApplicationRecord
  belongs_to :substack_user, optional: true

  validates :quotation, :comment_url, presence: true

  before_create :assign_position

  scope :chronological, -> { order(created_at: :desc) }
  # The display order on the Reviews pages — set manually by drag-to-reorder in the
  # admin (SubstackQuotation.reorder!); new quotations append to the end.
  scope :by_position, -> { order(:position, :id) }
  # Quotations complete enough to render as a triplet. Author is optional —
  # QuotationBlock renders the name as plain text when there's no profile link.
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

  # A digest of what a Reviews page renders from its quotations: which ones, in
  # what order, each one's last edit, and the page count (the pagination row).
  # Any local add/edit/delete/reorder that lands on (or shifts) a page changes it.
  def self.reviews_page_fingerprint(group, page_count)
    Digest::SHA256.hexdigest(JSON.generate([page_count, group.map { |q| [q.id, q.updated_at&.utc&.iso8601(6)] }]))
  end

  # Up to `count` random quotations from `scope` (default featurable), distinct
  # by quote text, and excluding any left on the given Substack post (no point
  # pointing a reader at the post they're already on).
  def self.sample_excluding(post_url, count, scope: featurable)
    scope = scope.where.not(post_url: post_url) if post_url.present?
    scope.includes(:substack_user).order(Arel.sql("RANDOM()")).limit(count * 5).to_a
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
      substack_user:  SubstackUser.identify(user_id: resolved.author_user_id, handle: resolved.author_handle,
                                            name: resolved.author_name)
    )
  end

  # Title + thumbnail always mirror the Substack post `post_url` names, so the
  # admin edit form exposes that URL alone.
  def populate_post_from_substack!(client: nil)
    resolved = Substack::PostMetadata.execute(post_url: post_url, client: client)
    assign_attributes(
      post_title:     resolved.post_title,
      post_image_url: resolved.post_image_url,
      post_id:        resolved.post_id
    )
  end

  # Drop the metadata derived from post_url, when that URL is cleared.
  def clear_post_metadata
    assign_attributes(post_title: nil, post_image_url: nil, post_id: nil)
  end

  private

  def assign_position
    self.position ||= (self.class.maximum(:position) || -1) + 1
  end
end
