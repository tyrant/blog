# frozen_string_literal: true

class Tag < ApplicationRecord
  has_many :blog_post_tags, dependent: :destroy
  has_many :posts, through: :blog_post_tags, source: :post

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :alphabetical, -> { order(Arel.sql("lower(name)")) }

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
