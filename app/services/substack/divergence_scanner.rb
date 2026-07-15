# frozen_string_literal: true

module Substack
  # Read-only audit of how each synced post's live Substack draft has drifted
  # from what Comfy would now rebuild — the manual Substack-only tweaks a resync
  # would clobber. Flags image sizes (imageSize wide/full), captions, extra
  # images, and extra blocks. Rebuilds the Comfy body without uploading images
  # (identity resolver) and never writes anything.
  class DivergenceScanner
    Finding = Struct.new(
      :post_id, :slug, :comfy_images, :substack_images, :image_sizes, :captions,
      :comfy_body_blocks, :substack_body_blocks, :flags, keyword_init: true
    )

    def self.execute(**kwargs)
      new(**kwargs).execute
    end

    def initialize(client: nil, pause: 0.3, progress: nil)
      @client = client || Substack::Client.new
      @pause = pause
      @progress = progress
    end

    def execute
      findings = substack_categorizations.filter_map do |categorization|
        finding = scan(categorization)
        @progress&.call(finding) if finding
        sleep @pause if @pause.positive?
        finding
      end
      findings
    end

    private

    def substack_categorizations
      Comfy::Cms::Categorization.joins(:category)
        .where(comfy_cms_categories: { label: "Substack" })
        .where.not(data: {})
        .order(:categorized_id)
    end

    def scan(categorization)
      substack_id = categorization.data["id"]
      post = categorization.categorized
      return nil if substack_id.blank? || !post.is_a?(Comfy::Blog::Post)

      comfy_body = HtmlToProseMirror.execute(html: post.content_cache.to_s, image_resolver: ->(src) { src })["content"]
      substack_body = body_of(JSON.parse(@client.get_draft(substack_id)["draft_body"].to_s)["content"])

      build_finding(post, comfy_body, substack_body)
    rescue => e
      Finding.new(post_id: categorization.categorized_id, slug: post.try(:slug), flags: ["ERROR: #{e.message[0, 70]}"])
    end

    def build_finding(post, comfy_body, substack_body)
      comfy_imgs = images(comfy_body)
      sub_imgs = images(substack_body)
      sizes = sub_imgs.filter_map { |img| image_size(img) }.reject { |s| s == "normal" }
      captions = sub_imgs.filter_map { |img| caption_text(img) }
      comfy_captions = comfy_imgs.count { |img| caption_text(img) }

      flags = []
      flags << "WIDTH" if sizes.any?
      flags << "CAPTION" if captions.size > comfy_captions
      flags << "IMG+#{sub_imgs.size - comfy_imgs.size}" if sub_imgs.size > comfy_imgs.size
      flags << "IMG-#{comfy_imgs.size - sub_imgs.size}" if comfy_imgs.size > sub_imgs.size
      flags << "BLOCKS+#{substack_body.size - comfy_body.size}" if substack_body.size > comfy_body.size

      Finding.new(post_id: post.id, slug: post.slug, comfy_images: comfy_imgs.size, substack_images: sub_imgs.size,
                  image_sizes: sizes, captions: captions, comfy_body_blocks: comfy_body.size,
                  substack_body_blocks: substack_body.size, flags: flags)
    end

    # A draft's body is everything above the mirror-managed "Original:" link.
    def body_of(content)
      index = content.index { |b| b["type"] == "heading" && block_text(b).strip.start_with?("Original:") }
      index ? content[0...index] : content
    end

    def images(content)
      found = []
      walk = lambda do |node|
        return unless node.is_a?(Hash)

        found << node if node["type"] == "captionedImage"
        Array(node["content"]).each { |child| walk.call(child) }
      end
      Array(content).each { |block| walk.call(block) }
      found
    end

    def image_size(captioned)
      image = Array(captioned["content"]).find { |c| c["type"] == "image2" }
      image&.dig("attrs", "imageSize")
    end

    def caption_text(captioned)
      caption = Array(captioned["content"]).find { |c| c["type"] == "caption" }
      caption && block_text(caption).presence
    end

    def block_text(node)
      Array(node["content"]).flat_map { |n| [n["text"]] + Array(n["content"]).map { |x| x["text"] } }.compact.join
    end
  end
end
