# frozen_string_literal: true

class Comfy::Blog::Post < ActiveRecord::Base

  self.table_name = "comfy_blog_posts"

  # Substack audience the post mirrors to (the draft's `audience` field). Labels
  # drive the post-form select; values are Substack's own.
  SUBSTACK_AUDIENCES = {
    "everyone"  => "Free (everyone)",
    "only_paid" => "Paid subscribers",
    "founding"  => "Founding members"
  }.freeze

  include Comfy::Cms::WithFragments
  include Comfy::Cms::WithCategories

  cms_has_revisions_for :fragments_attributes

  has_paper_trail only: [:slug]

  # -- Relationships -----------------------------------------------------------
  belongs_to :site,
    class_name: "Comfy::Cms::Site"

  has_many :blog_post_tags,
    foreign_key: :comfy_blog_post_id,
    dependent:   :destroy
  has_many :tags,
    through: :blog_post_tags

  # -- Validations -------------------------------------------------------------
  validates :title, :slug, :year, :month,
    presence: true
  validates :slug,
    uniqueness: { scope: %i[site_id year month] },
    format:     { with: %r{\A%*\w[a-z0-9_%-]*\z}i }
  validates :substack_audience,
    inclusion: { in: SUBSTACK_AUDIENCES.keys }

  # -- Scopes ------------------------------------------------------------------
  scope :published, -> { where(is_published: true) }
  scope :for_year,  ->(year) { where(year: year) }
  scope :for_month, ->(month) { where(month: month) }
  scope :title_matching, ->(query) {
    where("title ILIKE ?", "%#{sanitize_sql_like(query)}%") if query.present?
  }

  # -- Callbacks ---------------------------------------------------------------
  before_validation :set_slug,
                    :set_published_at,
                    :set_date

  # -- Instance Mathods --------------------------------------------------------
  def url(relative: false)
    public_blog_path = ComfyBlog.config.public_blog_path
    post_path = ["/", public_blog_path, year, month, slug].join("/").squeeze("/")
    [site.url(relative: relative), post_path].join
  end

  # Canonical link for a platform, e.g. socials_url_for(platform: 'medium').
  def socials_url_for(platform:)
    categorizations
      .joins(:category)
      .find_by(comfy_cms_categories: { label: platform.capitalize })
      &.url || ''
  end

  # Public cross-link to this post's Substack mirror — only once published (a
  # /p/ URL; unpublished categorizations hold the draft editor URL instead).
  def substack_url
    url = socials_url_for(platform: "substack")
    url if url.include?("/p/")
  end

  # Public cross-link to this post's Medium mirror (all are public URLs).
  def medium_url
    socials_url_for(platform: "medium").presence
  end

protected

  def set_slug
    self.slug ||= title.to_s.parameterize
  end

  def set_date
    self.year   = published_at.year
    self.month  = published_at.month
  end

  def set_published_at
    self.published_at ||= Time.zone.now
  end

end
