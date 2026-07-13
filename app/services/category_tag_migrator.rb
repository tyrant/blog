# frozen_string_literal: true

# Moves the topical blog categories to Tags: for each named category, upserts a
# Tag of the same name (reusing an imported Substack tag if one matches) and
# links it to every post in that category. Additive — the categories themselves
# are left intact. Wrapped in without_mirror so migrating local organisation
# never bulk-pushes assignments to Substack.
class CategoryTagMigrator
  LABELS = ["Whimsy", "NSFW", "Shite Advice"].freeze

  Result = Struct.new(:tags, :links_created, keyword_init: true)

  def self.execute(labels: LABELS)
    new(labels: labels).execute
  end

  def initialize(labels: LABELS)
    @labels = labels
  end

  def execute
    tags = []
    links = 0

    BlogPostTag.without_mirror do
      @labels.each do |label|
        category = Comfy::Cms::Category.find_by(label: label, categorized_type: "Comfy::Blog::Post")
        next unless category

        tag = Tag.upsert_from_substack(label)
        tags << tag.name
        category.categorizations.includes(:categorized).find_each do |categorization|
          post = categorization.categorized
          links += 1 if post.is_a?(Comfy::Blog::Post) && link(post, tag)
        end
      end
    end

    Result.new(tags: tags, links_created: links)
  end

  private

  def link(post, tag)
    join = BlogPostTag.find_or_initialize_by(comfy_blog_post_id: post.id, tag_id: tag.id)
    return false if join.persisted?

    join.save!
    true
  end
end
