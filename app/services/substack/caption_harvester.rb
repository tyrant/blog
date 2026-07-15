# frozen_string_literal: true

module Substack
  # Migrates the old implicit-caption posts to the explicit opt-in convention:
  # reads each synced post's existing Substack image captions and adds
  # class="caption" to the matching <p> in the Comfy source fragment, so a
  # resync reproduces the caption. Matches by (whitespace-normalised) text, so
  # an untouched caption maps to the paragraph it came from; a caption edited
  # on Substack (no matching paragraph) is reported as unmatched, left for a
  # human. Dry-run unless commit: true.
  class CaptionHarvester
    Result = Struct.new(:post_id, :slug, :captions, :marked, :unmatched, keyword_init: true)

    def self.execute(**kwargs)
      new(**kwargs).execute
    end

    def initialize(client: nil, commit: false, pause: 0.3, progress: nil, exclude: [])
      @client = client || Substack::Client.new
      @commit = commit
      @pause = pause
      @progress = progress
      @exclude = Array(exclude).map(&:to_i)
    end

    def execute
      substack_categorizations.filter_map do |categorization|
        result = harvest(categorization)
        @progress&.call(result) if result
        sleep @pause if @pause.positive?
        result
      end
    end

    private

    def substack_categorizations
      Comfy::Cms::Categorization.joins(:category)
        .where(comfy_cms_categories: { label: "Substack" })
        .where.not(data: {}).order(:categorized_id)
    end

    def harvest(categorization)
      substack_id = categorization.data["id"]
      post = categorization.categorized
      return nil if substack_id.blank? || !post.is_a?(Comfy::Blog::Post)
      return nil if @exclude.include?(post.id)

      captions = substack_captions(substack_id)
      return nil if captions.empty?

      fragment = post.fragments.find_by(identifier: "content")
      return Result.new(post_id: post.id, slug: post.slug, captions: captions.size, marked: 0, unmatched: captions) unless fragment

      html = Nokogiri::HTML.fragment(fragment.content.to_s)
      marked = []
      unmatched = []
      captions.each do |caption|
        paragraph = find_paragraph(html, caption)
        if paragraph
          paragraph["class"] = [paragraph["class"], "caption"].compact.join(" ").strip
          marked << caption
        else
          unmatched << caption
        end
      end

      if @commit && marked.any?
        fragment.update!(content: html.to_html)
        post.clear_content_cache!
      end

      Result.new(post_id: post.id, slug: post.slug, captions: captions.size, marked: marked.size, unmatched: unmatched)
    end

    def find_paragraph(html, caption)
      html.css("p").find do |para|
        para["class"].to_s.split.exclude?("caption") && normalize(para.text) == normalize(caption)
      end
    end

    def substack_captions(substack_id)
      doc = JSON.parse(@client.get_draft(substack_id)["draft_body"].to_s)
      captions = []
      walk = lambda do |node|
        return unless node.is_a?(Hash)

        if node["type"] == "captionedImage"
          caption = Array(node["content"]).find { |c| c["type"] == "caption" }
          captions << caption_text(caption) if caption
        end
        Array(node["content"]).each { |child| walk.call(child) }
      end
      Array(doc["content"]).each { |block| walk.call(block) }
      captions.map(&:presence).compact
    end

    def caption_text(caption)
      Array(caption["content"]).flat_map { |n| [n["text"]] + Array(n["content"]).map { |x| x["text"] } }.compact.join.strip
    end

    def normalize(text)
      text.to_s.gsub(/\s+/, " ").strip
    end
  end
end
