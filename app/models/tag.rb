# frozen_string_literal: true

class Tag < ApplicationRecord
  # The topical tags surfaced publicly (post pills + BLOG nav submenu). Migrated
  # off Comfy Categories, so these mirror the old ComfyCmsCategoryMethods labels.
  PUBLIC_NAMES = ["Whimsy", "NSFW", "Shite Advice"].freeze

  has_many :blog_post_tags, dependent: :destroy
  has_many :posts, through: :blog_post_tags, source: :post

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :alphabetical, -> { order(Arel.sql("lower(name)")) }
  scope :public_names, -> { where(name: PUBLIC_NAMES) }
  scope :nsfw_first, -> { order(Arel.sql("CASE WHEN name = 'NSFW' THEN 0 ELSE 1 END"), :name) }
  scope :nsfw_banished, ->(banish) { banish ? where.not(name: "NSFW") : all }

  def nsfw?
    name == "NSFW"
  end

  # Finds-or-creates a tag by name (case-insensitively), recording the Substack
  # tag uuid when one is supplied. The name is the merge key across imports.
  def self.upsert_from_substack(name, substack_tag_id = nil)
    clean = name.to_s.strip
    tag = where("lower(name) = ?", clean.downcase).first_or_initialize(name: clean)
    tag.substack_tag_id = substack_tag_id if substack_tag_id.present?
    tag.save!
    tag
  end
end
