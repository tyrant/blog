# frozen_string_literal: true

class BlogPostTag < ApplicationRecord
  belongs_to :post, class_name: "Comfy::Blog::Post", foreign_key: :comfy_blog_post_id
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :comfy_blog_post_id }

  after_create  :mirror_assign
  after_destroy :mirror_unassign

  # Wraps bulk work (imports, migrations) that links tags already present on
  # Substack, so the callbacks don't echo those links straight back to Substack.
  def self.without_mirror
    prev = Thread.current[:blog_post_tag_skip_mirror]
    Thread.current[:blog_post_tag_skip_mirror] = true
    yield
  ensure
    Thread.current[:blog_post_tag_skip_mirror] = prev
  end

  private

  def mirror_assign
    Substack::TagMirror.assign(self) unless Thread.current[:blog_post_tag_skip_mirror]
  end

  def mirror_unassign
    Substack::TagMirror.unassign(self) unless Thread.current[:blog_post_tag_skip_mirror]
  end
end
