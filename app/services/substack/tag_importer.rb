# frozen_string_literal: true

module Substack
  # Scrapes every Substack-linked, published post for its publication tags and
  # mirrors them into Comfy: upserting a Tag per unique name (recording its
  # Substack uuid) and linking it to the post. Reads FROM Substack, so linking
  # is wrapped in without_mirror to avoid echoing the same tags back.
  class TagImporter
    Result = Struct.new(:posts_scanned, :tags_seen, :links_created, keyword_init: true)

    def self.execute(**kwargs)
      new(**kwargs).execute
    end

    def initialize(client: Substack::Client.new, pause: 0.3, progress: nil)
      @client = client
      @pause = pause
      @progress = progress
    end

    def execute
      posts = 0
      tag_ids = Set.new
      links = 0

      BlogPostTag.without_mirror do
        substack_categorizations.find_each do |categorization|
          post = categorization.categorized
          next unless post.is_a?(Comfy::Blog::Post)

          remote = fetch(categorization.url) or next
          posts += 1
          remote_tags = remote["postTags"] || []
          remote_tags.each do |remote_tag|
            tag = Tag.upsert_from_substack(remote_tag["name"], remote_tag["id"])
            tag_ids << tag.id
            links += 1 if link(post, tag)
          end
          log("#{categorization.url} → #{remote_tags.size} tags")
          sleep @pause if @pause.positive?
        end
      end

      Result.new(posts_scanned: posts, tags_seen: tag_ids.size, links_created: links)
    end

    private

    def substack_categorizations
      Comfy::Cms::Categorization.joins(:category)
        .where(comfy_cms_categories: { label: "Substack" })
        .where.not(url: nil)
        .where("url LIKE ?", "%/p/%")
    end

    def fetch(url)
      @client.get_post(url)
    rescue => e
      log("skipped #{url}: #{e.message}")
      nil
    end

    def link(post, tag)
      join = BlogPostTag.find_or_initialize_by(comfy_blog_post_id: post.id, tag_id: tag.id)
      return false if join.persisted?

      join.save!
      true
    end

    def log(message)
      @progress&.call(message)
    end
  end
end
