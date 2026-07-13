# frozen_string_literal: true

module Substack
  # Mirrors a Comfy post/tag link to Substack: assigning or unassigning the
  # matching publication tag on the post's Substack draft. Best-effort — a
  # missing link (tag not on Substack, or post not synced) or an API error is
  # logged, never raised, so tagging in the admin never fails on Substack.
  class TagMirror
    def self.assign(join)
      new(join).assign
    end

    def self.unassign(join)
      new(join).unassign
    end

    def initialize(join, client: Substack::Client.new)
      @join = join
      @client = client
    end

    def assign
      with_ids { |post_id, tag_id| @client.add_tag(post_id, tag_id) }
    end

    def unassign
      with_ids { |post_id, tag_id| @client.remove_tag(post_id, tag_id) }
    end

    private

    def with_ids
      tag_id = @join.tag&.substack_tag_id
      post_id = substack_post_id
      return if tag_id.blank? || post_id.blank?

      yield(post_id, tag_id)
    rescue => e
      Rails.logger.warn("[TagMirror] #{e.class}: #{e.message}")
    end

    def substack_post_id
      @join.post.categorizations.joins(:category)
        .find_by(comfy_cms_categories: { label: "Substack" })&.data&.dig("id")
    end
  end
end
