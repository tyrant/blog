# frozen_string_literal: true

# Phase 2 of the Categories to Tags migration: deletes each topical category
# once its post set is in exact parity with its Tag. Per-label guarded — a
# category that has drifted from its tag is left untouched, never force-deleted.
# The Category cascade-destroys its categorizations; the Tag is left intact.
class TopicalCategoryRetirer
  LABELS = CategoryTagMigrator::LABELS

  Result = Struct.new(:deleted, :skipped, keyword_init: true)

  def self.execute(labels: LABELS)
    new(labels: labels).execute
  end

  def initialize(labels: LABELS)
    @labels = labels
  end

  def execute
    deleted = []
    skipped = []

    @labels.each do |label|
      category = Comfy::Cms::Category.find_by(label: label, categorized_type: "Comfy::Blog::Post")
      next unless category

      if in_parity?(category, label)
        category.destroy!
        deleted << label
      else
        skipped << label
      end
    end

    Result.new(deleted: deleted, skipped: skipped)
  end

  private

  def in_parity?(category, label)
    category_post_ids(category) == tag_post_ids(label)
  end

  def category_post_ids(category)
    category.categorizations.pluck(:categorized_id).sort
  end

  def tag_post_ids(label)
    tag = Tag.where("lower(name) = ?", label.downcase).first
    tag ? tag.posts.pluck(:id).sort : []
  end
end
